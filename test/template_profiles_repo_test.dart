import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeetools/features/epub_templater/data/template_profiles_repo.dart';
import 'package:zeetools/features/epub_templater/domain/template_project.dart';

void main() {
  test('cada perfil es un archivo JSON con su nombre; los signos no válidos van en ancho completo', () async {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('perfiles');
    final repo = TemplateProfilesRepositoryImpl(await SharedPreferences.getInstance(), dir.path);
    await repo.saveProfiles({'Serie: A?': TemplateProject.initial(), 'Otra': TemplateProject.initial()});
    expect(dir.listSync().map((f) => f.uri.pathSegments.last).toSet(), {'Serie： A？.json', 'Otra.json'});
    expect(repo.getProfiles().keys.toSet(), {'Serie: A?', 'Otra'});

    await repo.saveProfiles({'Otra': TemplateProject.initial()});
    expect(repo.getProfiles().keys, ['Otra']);

    // Un archivo copiado a mano en la carpeta es un perfil más.
    File('${dir.path}/Copiado.json').writeAsStringSync(jsonEncode(TemplateProject.initial()));
    expect(repo.getProfiles().keys.toSet(), {'Otra', 'Copiado'});
  });

  test('los perfiles guardados en las preferencias pasan a la carpeta', () async {
    SharedPreferences.setMockInitialValues({'epub_templater_profiles': jsonEncode({'Antiguo': TemplateProject.initial()})});
    final prefs = await SharedPreferences.getInstance();
    final dir = Directory.systemTemp.createTempSync('perfiles');
    final repo = TemplateProfilesRepositoryImpl(prefs, dir.path);
    expect(repo.getProfiles().keys, ['Antiguo']);
    expect(prefs.getString('epub_templater_profiles'), isNull);
    expect(File('${dir.path}/Antiguo.json').existsSync(), isTrue);
  });
}
