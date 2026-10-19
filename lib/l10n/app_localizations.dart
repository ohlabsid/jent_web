import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @textName.
  ///
  /// In id, this message translates to:
  /// **'Nama'**
  String get textName;

  /// No description provided for @textNameHint.
  ///
  /// In id, this message translates to:
  /// **'Nama anda'**
  String get textNameHint;

  /// No description provided for @textFrom.
  ///
  /// In id, this message translates to:
  /// **'Dari'**
  String get textFrom;

  /// No description provided for @textFromHint.
  ///
  /// In id, this message translates to:
  /// **'anda@email.com'**
  String get textFromHint;

  /// No description provided for @textSubject.
  ///
  /// In id, this message translates to:
  /// **'Subjek'**
  String get textSubject;

  /// No description provided for @textSubjectHint.
  ///
  /// In id, this message translates to:
  /// **'Subjek'**
  String get textSubjectHint;

  /// No description provided for @textWriteYourMessageHint.
  ///
  /// In id, this message translates to:
  /// **'Tulis pesan anda...'**
  String get textWriteYourMessageHint;

  /// No description provided for @textSend.
  ///
  /// In id, this message translates to:
  /// **'Kirim'**
  String get textSend;

  /// No description provided for @textSendError.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengirim, coba lagi'**
  String get textSendError;

  /// No description provided for @textSentWithIcon.
  ///
  /// In id, this message translates to:
  /// **'Terkirim'**
  String get textSentWithIcon;

  /// No description provided for @textCaptchaTitle.
  ///
  /// In id, this message translates to:
  /// **'Perlindungan spam'**
  String get textCaptchaTitle;

  /// No description provided for @textCaptchaHint.
  ///
  /// In id, this message translates to:
  /// **'Verifikasi bahwa Anda manusia'**
  String get textCaptchaHint;

  /// No description provided for @textCaptchaVerified.
  ///
  /// In id, this message translates to:
  /// **'Terverifikasi'**
  String get textCaptchaVerified;

  /// No description provided for @textFinder.
  ///
  /// In id, this message translates to:
  /// **'Temuan'**
  String get textFinder;

  /// No description provided for @textEmail.
  ///
  /// In id, this message translates to:
  /// **'Email'**
  String get textEmail;

  /// No description provided for @textNotes.
  ///
  /// In id, this message translates to:
  /// **'Catatan'**
  String get textNotes;

  /// No description provided for @textMusic.
  ///
  /// In id, this message translates to:
  /// **'Musik'**
  String get textMusic;

  /// No description provided for @textPhotos.
  ///
  /// In id, this message translates to:
  /// **'Foto'**
  String get textPhotos;

  /// No description provided for @textSpotlight.
  ///
  /// In id, this message translates to:
  /// **'Sorotan'**
  String get textSpotlight;

  /// No description provided for @menuFile.
  ///
  /// In id, this message translates to:
  /// **'Berkas'**
  String get menuFile;

  /// No description provided for @menuEdit.
  ///
  /// In id, this message translates to:
  /// **'Ubah'**
  String get menuEdit;

  /// No description provided for @menuView.
  ///
  /// In id, this message translates to:
  /// **'Lihat'**
  String get menuView;

  /// No description provided for @welcomeMessage.
  ///
  /// In id, this message translates to:
  /// **'Selamat datang'**
  String get welcomeMessage;

  /// No description provided for @dialogDeny.
  ///
  /// In id, this message translates to:
  /// **'Tolak'**
  String get dialogDeny;

  /// No description provided for @dialogAllow.
  ///
  /// In id, this message translates to:
  /// **'Izinkan'**
  String get dialogAllow;

  /// No description provided for @musicNowPlaying.
  ///
  /// In id, this message translates to:
  /// **'Sedang diputar'**
  String get musicNowPlaying;

  /// No description provided for @musicPaused.
  ///
  /// In id, this message translates to:
  /// **'Dijeda'**
  String get musicPaused;

  /// No description provided for @musicYourPlaylist.
  ///
  /// In id, this message translates to:
  /// **'Playlist kamu'**
  String get musicYourPlaylist;

  /// No description provided for @musicUnknownArtist.
  ///
  /// In id, this message translates to:
  /// **'Artis tidak dikenal'**
  String get musicUnknownArtist;

  /// No description provided for @musicSearchHint.
  ///
  /// In id, this message translates to:
  /// **'Cari'**
  String get musicSearchHint;

  /// No description provided for @musicNoResults.
  ///
  /// In id, this message translates to:
  /// **'Lagu tidak ditemukan, coba kata lain'**
  String get musicNoResults;

  /// No description provided for @dialogClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get dialogClose;

  /// No description provided for @photosBackToGallery.
  ///
  /// In id, this message translates to:
  /// **'Kembali ke galeri'**
  String get photosBackToGallery;

  /// No description provided for @photosPinTitle.
  ///
  /// In id, this message translates to:
  /// **'Masukkan PIN untuk membuka Foto'**
  String get photosPinTitle;

  /// No description provided for @photosPinUnlock.
  ///
  /// In id, this message translates to:
  /// **'Buka'**
  String get photosPinUnlock;

  /// No description provided for @photosPinCancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get photosPinCancel;

  /// No description provided for @photosPinHint.
  ///
  /// In id, this message translates to:
  /// **'PIN 4 digit'**
  String get photosPinHint;

  /// No description provided for @photosAccessDenied.
  ///
  /// In id, this message translates to:
  /// **'Anda tidak punya akses untuk melihat foto'**
  String get photosAccessDenied;

  /// No description provided for @photosViewGeneral.
  ///
  /// In id, this message translates to:
  /// **'Lihat foto umum'**
  String get photosViewGeneral;

  /// No description provided for @notesFolders.
  ///
  /// In id, this message translates to:
  /// **'Folder'**
  String get notesFolders;

  /// No description provided for @notesSearchHint.
  ///
  /// In id, this message translates to:
  /// **'Cari'**
  String get notesSearchHint;

  /// No description provided for @notesNewNote.
  ///
  /// In id, this message translates to:
  /// **'Catatan Baru'**
  String get notesNewNote;

  /// No description provided for @notesDeleteNote.
  ///
  /// In id, this message translates to:
  /// **'Hapus Catatan'**
  String get notesDeleteNote;

  /// No description provided for @notesEmpty.
  ///
  /// In id, this message translates to:
  /// **'Tidak Ada Catatan'**
  String get notesEmpty;

  /// No description provided for @notesPinTitle.
  ///
  /// In id, this message translates to:
  /// **'Masukkan PIN untuk membuka Catatan'**
  String get notesPinTitle;

  /// No description provided for @notesAccessDenied.
  ///
  /// In id, this message translates to:
  /// **'Anda tidak punya akses untuk melihat catatan'**
  String get notesAccessDenied;

  /// No description provided for @notesViewGeneral.
  ///
  /// In id, this message translates to:
  /// **'Lihat catatan umum'**
  String get notesViewGeneral;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
