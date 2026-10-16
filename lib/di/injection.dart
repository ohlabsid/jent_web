import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:jent_web/di/injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit()
void configureDependencies() => getIt.init();

@module
abstract class AppModule {
  @Named('emailUsername')
  String get emailUsername =>
      const String.fromEnvironment('EMAIL_USERNAME');

  @Named('emailPassword')
  String get emailPassword =>
      const String.fromEnvironment('EMAIL_PASSWORD');

  @Named('emailRecipient')
  String get emailRecipient =>
      const String.fromEnvironment('EMAIL_RECIPIENT');
}
