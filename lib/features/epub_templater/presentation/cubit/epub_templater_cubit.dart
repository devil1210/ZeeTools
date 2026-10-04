import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '/common/process/native_tools_repo.dart';
import '/common/utils/either.dart';
import '/common/utils/uuid_v7.dart';
import '../../../image_optimizer/data/image_optimizer_repo.dart';
import '../../../image_optimizer/data/image_optimizer_settings_repo.dart';
import '../../../image_optimizer/domain/image_format.dart';
import '../../../image_optimizer/domain/image_job.dart';
import '../../../image_optimizer/domain/optimization_options.dart';
import '../../../image_optimizer/domain/optimization_outcome.dart';
import '../../data/epub_templater_repo.dart';
import '../../data/template_profiles_repo.dart';
import '../../data/system_fonts.dart';
import '../../domain/book_metadata.dart';
import '../../domain/embedded_font.dart';
import '../../domain/section_kind.dart';
import '../../domain/template_project.dart';
import '../../domain/template_section.dart';

part 'epub_templater_state.dart';
part 'epub_templater_cubit.freezed.dart';

class EpubTemplaterCubit extends Cubit<EpubTemplaterState> {
  EpubTemplaterCubit(this._repo, this._profilesRepo, this._imageRepo, this._imageSettings)
    : super(
        EpubTemplaterState(
          project: TemplateProject.initial(),
          allowedFormats: _imageSettings.getAllowedFormats(),
          allowConversion: _imageSettings.getAllowConversion(),
          qualityMode: _imageSettings.getQualityMode(),
        ),
      ) {
    var profiles = _profilesRepo.getProfiles();
    var draft = _profilesRepo.getDraft();
    // La primera ejecución arranca con un perfil que muestra todos los tipos de sección.
    if (draft == null && profiles.isEmpty) {
      draft = TemplateProject.allSections();
      profiles = {allSectionsProfile: draft};
      _profilesRepo.saveProfiles(profiles);
    }
    draft ??= TemplateProject.initial();
    emit(state.copyWith(project: _prepared(draft), profiles: profiles, selectedKey: draft.sections.firstOrNull?.key));
  }

  static const allSectionsProfile = 'Todas las secciones';

  final EpubTemplaterRepository _repo;
  final TemplateProfilesRepository _profilesRepo;
  final ImageOptimizerRepository _imageRepo;
  final ImageOptimizerSettingsRepository _imageSettings;
  Timer? _draftDebounce;

  @override
  Future<void> close() async {
    if (_draftDebounce?.isActive ?? false) {
      _draftDebounce!.cancel();
      await _profilesRepo.saveDraft(state.project);
    }
    _discardJobs(state.imageJobs.values);
    return super.close();
  }

  static TemplateProject _prepared(TemplateProject p) {
    final withId = p.metadata.identifier.isEmpty ? p.copyWith(metadata: p.metadata.copyWith(identifier: uuidV7())) : p;
    return withId.copyWith(sections: _byMatter(withId.sections));
  }

  // Orden estable por división: una sección que cambia de división queda al
  // principio de la siguiente o al final de la anterior.
  static List<TemplateSection> _byMatter(List<TemplateSection> sections) {
    final indexed = sections.indexed.toList()..sort((a, b) => a.$2.matter.index != b.$2.matter.index ? a.$2.matter.index.compareTo(b.$2.matter.index) : a.$1.compareTo(b.$1));
    return [for (final (_, s) in indexed) s];
  }

  void _setProject(TemplateProject project, {String? selectedKey, bool replaced = false}) {
    final ordered = project.copyWith(sections: _byMatter(project.sections));
    emit(state.copyWith(project: ordered, selectedKey: selectedKey ?? state.selectedKey, revision: replaced ? state.revision + 1 : state.revision));
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 500), () => _profilesRepo.saveDraft(state.project));
  }

  void _message(String text, {bool isError = false}) => emit(state.copyWith(message: EpubTemplaterMessage(text, isError: isError)));

  // ── Metadatos ──────────────────────────────────────────────────────────────

  void updateMetadata(BookMetadata Function(BookMetadata m) update) => _setProject(state.project.copyWith(metadata: update(state.project.metadata)));

  void regenerateIdentifier() => updateMetadata((m) => m.copyWith(identifier: uuidV7()));

  // ── Fuentes ────────────────────────────────────────────────────────────────

  void setGuideComments(bool value) => _setProject(state.project.copyWith(guideComments: value));

  void updateFonts(List<EmbeddedFont> fonts) => _setProject(state.project.copyWith(fonts: fonts));

  Future<List<FontFace>> systemFonts() => _repo.systemFonts();

  // ── Secciones ──────────────────────────────────────────────────────────────

  void select(String key) => emit(state.copyWith(selectedKey: key));

  // Tras la sección seleccionada si es de la misma división; si no, al final de la suya.
  void addSection(SectionKind kind) {
    final sections = [...state.project.sections];
    final number = sections.where((s) => s.kind == kind).length + 1;
    final section = TemplateSection.of(kind, number: number);
    final selectedIndex = sections.indexWhere((s) => s.key == state.selectedKey);
    final sameMatter = selectedIndex >= 0 && sections[selectedIndex].matter == section.matter;
    sections.insert(sameMatter ? selectedIndex + 1 : sections.lastIndexWhere((s) => s.matter.index <= section.matter.index) + 1, section);
    _setProject(state.project.copyWith(sections: sections), selectedKey: section.key);
  }

  void duplicateSection(String key) {
    final sections = [...state.project.sections];
    final index = sections.indexWhere((s) => s.key == key);
    if (index < 0) return;
    final original = sections[index];
    final copy = original.copyWith(key: uuidV7(), fileName: '${original.fileName}_copia');
    sections.insert(index + 1, copy);
    _setProject(state.project.copyWith(sections: sections), selectedKey: copy.key);
  }

  void removeSection(String key) {
    final sections = [...state.project.sections];
    final index = sections.indexWhere((s) => s.key == key);
    if (index < 0) return;
    sections.removeAt(index);
    final neighbour = sections.isEmpty ? null : sections[index.clamp(0, sections.length - 1)].key;
    _setProject(state.project.copyWith(sections: sections), selectedKey: neighbour);
  }

  // [index] es la posición dentro de la división de destino.
  void moveSection(String key, BookMatter matter, int index) {
    final sections = [...state.project.sections];
    final from = sections.indexWhere((s) => s.key == key);
    if (from < 0) return;
    final moved = sections.removeAt(from).copyWith(matter: matter);
    final groupStart = sections.indexWhere((s) => s.matter.index >= matter.index);
    final start = groupStart < 0 ? sections.length : groupStart;
    final groupLength = sections.where((s) => s.matter == matter).length;
    sections.insert(start + index.clamp(0, groupLength), moved);
    _setProject(state.project.copyWith(sections: sections));
  }

  void updateSection(String key, TemplateSection Function(TemplateSection s) update) {
    _setProject(state.project.copyWith(sections: [for (final s in state.project.sections) s.key == key ? update(s) : s]));
  }

  // Los valores que seguían el tipo anterior adoptan los del nuevo; lo editado se conserva.
  void changeKind(String key, SectionKind kind) => updateSection(key, (s) {
    final fresh = TemplateSection.of(kind, number: state.project.sections.where((x) => x.kind == kind).length + 1);
    final old = TemplateSection.of(s.kind);
    bool untouched(String Function(TemplateSection x) field) => field(s) == field(old) || (s.kind.numbered && field(s).startsWith(field(old).replaceAll(RegExp(r'\d+$'), '')));
    return s.copyWith(
      kind: kind,
      fileName: untouched((x) => x.fileName) ? fresh.fileName : s.fileName,
      title: untouched((x) => x.title) ? fresh.title : s.title,
      epubType: kind.epubType,
      matter: kind.matter,
      inToc: kind.inToc,
      hideHeading: kind.hideHeading,
      images: kind.acceptsImages ? s.images : const [],
    );
  });

  // ── Perfiles ───────────────────────────────────────────────────────────────

  // El identificador es propio de cada libro y no viaja en el perfil.
  Future<void> saveProfile(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final project = state.project;
    final profiles = {...state.profiles, trimmed: project.copyWith(metadata: project.metadata.copyWith(identifier: ''))};
    emit(state.copyWith(profiles: profiles, message: EpubTemplaterMessage('Perfil «$trimmed» guardado.')));
    await _profilesRepo.saveProfiles(profiles);
  }

  void loadProfile(String name) {
    final profile = state.profiles[name.trim()];
    if (profile == null) return;
    _setProject(_prepared(profile), selectedKey: profile.sections.firstOrNull?.key, replaced: true);
    _message('Perfil «${name.trim()}» cargado.');
  }

  Future<void> deleteProfile(String name) async {
    final profiles = {...state.profiles}..remove(name.trim());
    emit(state.copyWith(profiles: profiles, message: EpubTemplaterMessage('Perfil «${name.trim()}» eliminado.')));
    await _profilesRepo.saveProfiles(profiles);
  }

  void resetSections() {
    final sections = TemplateProject.initial().sections;
    _setProject(state.project.copyWith(sections: sections), selectedKey: sections.firstOrNull?.key, replaced: true);
  }

  void resetProject() {
    final project = _prepared(TemplateProject.initial());
    _setProject(project, selectedKey: project.sections.firstOrNull?.key, replaced: true);
  }

  // ── Generación ─────────────────────────────────────────────────────────────

  Future<GeneratedEpub?> generate() async {
    emit(state.copyWith(generating: true));
    final result = await _repo.generate(state.project, optimized: state.optimizedImages);
    emit(state.copyWith(generating: false));
    return result.fold((error) {
      _message('No se pudo generar el EPUB: $error', isError: true);
      return null;
    }, (epub) => epub);
  }

  void notify(String text, {bool isError = false}) => _message(text, isError: isError);

  // ── Imágenes ───────────────────────────────────────────────────────────────

  // Las opciones son las mismas que las del optimizador de imágenes.
  Future<void> setAllowedFormats(List<ImageFormat> formats) async {
    _resetJobs();
    emit(state.copyWith(allowedFormats: formats));
    await _imageSettings.saveAllowedFormats(formats);
  }

  Future<void> setQualityMode(QualityMode mode) async {
    _resetJobs();
    emit(state.copyWith(qualityMode: mode));
    await _imageSettings.saveQualityMode(mode);
  }

  Future<void> setAllowConversion(bool value) async {
    _resetJobs();
    emit(state.copyWith(allowConversion: value));
    await _imageSettings.saveAllowConversion(value);
  }

  // Un resultado deja de valer si cambian las opciones con que se obtuvo.
  void _resetJobs() {
    _discardJobs(state.imageJobs.values);
    emit(state.copyWith(imageJobs: {}));
  }

  void _discardJobs(Iterable<ImageJob> jobs) {
    for (final job in jobs) {
      if (job is DoneJob) _imageRepo.discardResult(job.outcome);
    }
  }

  void discardOptimization(String path) {
    final job = state.imageJobs[path];
    if (job == null) return;
    _discardJobs([job]);
    emit(state.copyWith(imageJobs: {...state.imageJobs}..remove(path)));
  }

  // Optimiza las imágenes que aún no tienen resultado.
  Future<void> optimizeImages() async {
    final pending = state.imagePaths.where((path) => state.imageJobs[path] == null).toList();
    if (pending.isEmpty || state.optimizing) return;
    emit(state.copyWith(optimizing: true, optimizeStatus: 'Preparando herramientas…'));
    final NativeToolset tools;
    try {
      tools = await _imageRepo.ensureTools(onProgress: (m) => emit(state.copyWith(optimizeStatus: m)));
    } catch (e) {
      emit(state.copyWith(optimizing: false, optimizeStatus: null));
      _message('No se pudieron preparar las herramientas de imagen: $e', isError: true);
      return;
    }
    final options = OptimizationOptions(allowedFormats: state.allowedFormats.toSet(), qualityMode: state.qualityMode, allowConversion: state.allowConversion);
    for (final (i, path) in pending.indexed) {
      if (isClosed) return;
      emit(state.copyWith(optimizeStatus: 'Optimizando ${i + 1} de ${pending.length}…', imageJobs: {...state.imageJobs, path: const ImageJob.running()}));
      final outcome = await _imageRepo.optimizeFile(path, options, tools);
      if (isClosed) return;
      emit(state.copyWith(imageJobs: {...state.imageJobs, path: ImageJob.done(outcome)}));
    }
    emit(state.copyWith(optimizing: false, optimizeStatus: null));
  }
}
