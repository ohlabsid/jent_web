// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:jent_web/data/audio/just_audio_service.dart' as _i737;
import 'package:jent_web/data/datasources/email_datasource.dart' as _i763;
import 'package:jent_web/data/datasources/music_remote_datasource.dart'
    as _i361;
import 'package:jent_web/data/datasources/notes_remote_datasource.dart'
    as _i253;
import 'package:jent_web/data/repositories/email_repository_impl.dart' as _i724;
import 'package:jent_web/di/injection.dart' as _i786;
import 'package:jent_web/domain/repositories/email_repository.dart' as _i414;
import 'package:jent_web/domain/repositories/music_audio_service.dart' as _i528;
import 'package:jent_web/domain/usecases/send_email_usecase.dart' as _i343;
import 'package:jent_web/features/ignite/bloc/ignite_bloc.dart' as _i640;
import 'package:jent_web/features/mail/bloc/mail_bloc.dart' as _i1032;
import 'package:jent_web/features/music/bloc/music_bloc.dart' as _i823;
import 'package:jent_web/features/notes/bloc/notes_bloc.dart' as _i529;
import 'package:jent_web/features/photos/bloc/photos_bloc.dart' as _i195;
import 'package:jent_web/features/wallpaper/bloc/wallpaper_bloc.dart' as _i228;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final appModule = _$AppModule();
    gh.factory<_i640.IgniteBloc>(() => _i640.IgniteBloc());
    gh.factory<_i195.PhotosBloc>(() => _i195.PhotosBloc());
    gh.factory<_i228.WallpaperBloc>(() => _i228.WallpaperBloc());
    gh.lazySingleton<_i361.MusicRemoteDataSource>(
      () => _i361.MusicRemoteDataSource(),
    );
    gh.lazySingleton<_i253.NotesRemoteDataSource>(
      () => _i253.NotesRemoteDataSource(),
    );
    gh.factory<String>(
      () => appModule.emailRecipient,
      instanceName: 'emailRecipient',
    );
    gh.lazySingleton<_i528.MusicAudioService>(() => _i737.JustAudioService());
    gh.factory<String>(
      () => appModule.emailUsername,
      instanceName: 'emailUsername',
    );
    gh.factory<String>(
      () => appModule.emailPassword,
      instanceName: 'emailPassword',
    );
    gh.factory<_i529.NotesBloc>(
      () => _i529.NotesBloc(gh<_i253.NotesRemoteDataSource>()),
    );
    gh.factory<_i763.EmailDatasource>(
      () => _i763.EmailDatasource(
        gh<String>(instanceName: 'emailUsername'),
        gh<String>(instanceName: 'emailPassword'),
        gh<String>(instanceName: 'emailRecipient'),
      ),
    );
    gh.lazySingleton<_i414.EmailRepository>(
      () => _i724.EmailRepositoryImpl(gh<_i763.EmailDatasource>()),
    );
    gh.factory<_i343.SendEmailUseCase>(
      () => _i343.SendEmailUseCase(gh<_i414.EmailRepository>()),
    );
    gh.factory<_i823.MusicBloc>(
      () => _i823.MusicBloc(
        gh<_i528.MusicAudioService>(),
        gh<_i361.MusicRemoteDataSource>(),
      ),
    );
    gh.factory<_i1032.MailBloc>(
      () => _i1032.MailBloc(gh<_i343.SendEmailUseCase>()),
    );
    return this;
  }
}

class _$AppModule extends _i786.AppModule {}
