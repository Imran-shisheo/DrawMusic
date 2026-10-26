import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fil.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_th.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('es'),
    Locale('fil'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('th'),
    Locale('vi'),
  ];

  /// No description provided for @pageUnavailableReturnHome.
  ///
  /// In en, this message translates to:
  /// **'Page unavailable. Return home'**
  String get pageUnavailableReturnHome;

  /// No description provided for @newDrawing.
  ///
  /// In en, this message translates to:
  /// **'New drawing'**
  String get newDrawing;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @scribblesong.
  ///
  /// In en, this message translates to:
  /// **'ScribbleSong'**
  String get scribblesong;

  /// No description provided for @aLittleLineALittleMusic.
  ///
  /// In en, this message translates to:
  /// **'A little line.\nA little music.'**
  String get aLittleLineALittleMusic;

  /// No description provided for @turnYourMarksIntoAMelodyStartWithABlankPageAndSeeWhereItTa.
  ///
  /// In en, this message translates to:
  /// **'Turn your marks into a melody. Start with a blank page and see where it takes you.'**
  String get turnYourMarksIntoAMelodyStartWithABlankPageAndSeeWhereItTa;

  /// No description provided for @makeYourFirstLoop.
  ///
  /// In en, this message translates to:
  /// **'Make your first loop'**
  String get makeYourFirstLoop;

  /// No description provided for @startDrawing.
  ///
  /// In en, this message translates to:
  /// **'Start drawing'**
  String get startDrawing;

  /// No description provided for @youCanUndoThisFromTheConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'You can undo this from the confirmation message.'**
  String get youCanUndoThisFromTheConfirmationMessage;

  /// No description provided for @keepDrawing.
  ///
  /// In en, this message translates to:
  /// **'Keep drawing'**
  String get keepDrawing;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @drawingDeleted.
  ///
  /// In en, this message translates to:
  /// **'Drawing deleted'**
  String get drawingDeleted;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @couldNotRestoreTheDrawingItsFilesArePreserved.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the drawing. Its files are preserved.'**
  String get couldNotRestoreTheDrawingItsFilesArePreserved;

  /// No description provided for @couldNotChangeThisDrawingPleaseRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not change this drawing. Please retry.'**
  String get couldNotChangeThisDrawingPleaseRetry;

  /// No description provided for @yourDrawings.
  ///
  /// In en, this message translates to:
  /// **'Your drawings'**
  String get yourDrawings;

  /// No description provided for @refreshDrafts.
  ///
  /// In en, this message translates to:
  /// **'Refresh drafts'**
  String get refreshDrafts;

  /// No description provided for @couldNotLoadYourDrawings.
  ///
  /// In en, this message translates to:
  /// **'Could not load your drawings.'**
  String get couldNotLoadYourDrawings;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @yourDrawingsWillLiveHereCreateANewDrawingToBegin.
  ///
  /// In en, this message translates to:
  /// **'Your drawings will live here.\nCreate a new drawing to begin.'**
  String get yourDrawingsWillLiveHereCreateANewDrawingToBegin;

  /// No description provided for @aDrawingCouldNotBeRecovered.
  ///
  /// In en, this message translates to:
  /// **'A drawing could not be recovered'**
  String get aDrawingCouldNotBeRecovered;

  /// No description provided for @theOriginalFilesArePreserved.
  ///
  /// In en, this message translates to:
  /// **'The original files are preserved.'**
  String get theOriginalFilesArePreserved;

  /// No description provided for @deleteDamagedDrawing.
  ///
  /// In en, this message translates to:
  /// **'Delete damaged drawing'**
  String get deleteDamagedDrawing;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @exportShare.
  ///
  /// In en, this message translates to:
  /// **'Export / share'**
  String get exportShare;

  /// No description provided for @drafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get drafts;

  /// No description provided for @exports.
  ///
  /// In en, this message translates to:
  /// **'Exports'**
  String get exports;

  /// No description provided for @drawYourMelody.
  ///
  /// In en, this message translates to:
  /// **'Draw your melody'**
  String get drawYourMelody;

  /// No description provided for @leftToRightFollowsTimeHigherMarksMakeHigherNotesVerticalMa.
  ///
  /// In en, this message translates to:
  /// **'Left to right follows time. Higher marks make higher notes. Vertical marks can form chords.'**
  String get leftToRightFollowsTimeHigherMarksMakeHigherNotesVerticalMa;

  /// No description provided for @chooseAVoice.
  ///
  /// In en, this message translates to:
  /// **'Choose a voice'**
  String get chooseAVoice;

  /// No description provided for @eachNamedColorPlaysItsOwnOriginalInstrumentEraseUndoAndRed.
  ///
  /// In en, this message translates to:
  /// **'Each named color plays its own original instrument. Erase, Undo and Redo to explore.'**
  String get eachNamedColorPlaysItsOwnOriginalInstrumentEraseUndoAndRed;

  /// No description provided for @playAndChangeIt.
  ///
  /// In en, this message translates to:
  /// **'Play and change it'**
  String get playAndChangeIt;

  /// No description provided for @tapPlayToHearTheLoopTempoChangesArriveOnABeatDrawingChange.
  ///
  /// In en, this message translates to:
  /// **'Tap Play to hear the loop. Tempo changes arrive on a beat; drawing changes arrive on a loop. Pause and Replay keep you in control.'**
  String get tapPlayToHearTheLoopTempoChangesArriveOnABeatDrawingChange;

  /// No description provided for @keepAndShareYourWork.
  ///
  /// In en, this message translates to:
  /// **'Keep and share your work'**
  String get keepAndShareYourWork;

  /// No description provided for @drawingsSaveOnThisDeviceReopenThemFromDraftsOrExportMidiWa.
  ///
  /// In en, this message translates to:
  /// **'Drawings save on this device. Reopen them from Drafts, or export MIDI, WAV and MP4. Sharing starts only when you choose it.'**
  String get drawingsSaveOnThisDeviceReopenThemFromDraftsOrExportMidiWa;

  /// No description provided for @noAccountIsNeededYouCanReplayThisGuideFromSettingsHelp.
  ///
  /// In en, this message translates to:
  /// **'No account is needed. You can replay this guide from Settings & help.'**
  String get noAccountIsNeededYouCanReplayThisGuideFromSettingsHelp;

  /// No description provided for @skipGuide.
  ///
  /// In en, this message translates to:
  /// **'Skip guide'**
  String get skipGuide;

  /// No description provided for @continueForNow.
  ///
  /// In en, this message translates to:
  /// **'Continue for now'**
  String get continueForNow;

  /// No description provided for @backToSettings.
  ///
  /// In en, this message translates to:
  /// **'Back to settings'**
  String get backToSettings;

  /// No description provided for @skipTips.
  ///
  /// In en, this message translates to:
  /// **'Skip tips'**
  String get skipTips;

  /// No description provided for @exportThisLoop.
  ///
  /// In en, this message translates to:
  /// **'Export this loop'**
  String get exportThisLoop;

  /// No description provided for @midiContainsNotesAndInstrumentInstructionsItMaySoundDiffer.
  ///
  /// In en, this message translates to:
  /// **'MIDI contains notes and instrument instructions. It may sound different in another player.'**
  String get midiContainsNotesAndInstrumentInstructionsItMaySoundDiffer;

  /// No description provided for @exportMidi.
  ///
  /// In en, this message translates to:
  /// **'Export MIDI'**
  String get exportMidi;

  /// No description provided for @exportWav.
  ///
  /// In en, this message translates to:
  /// **'Export WAV'**
  String get exportWav;

  /// No description provided for @mp4AnimatesThisDrawingWithItsMusicVideoExportCancelsIfYouL.
  ///
  /// In en, this message translates to:
  /// **'MP4 animates this drawing with its music. Video export cancels if you leave the app.'**
  String get mp4AnimatesThisDrawingWithItsMusicVideoExportCancelsIfYouL;

  /// No description provided for @hd1080135030Fps.
  ///
  /// In en, this message translates to:
  /// **'HD · 1080 × 1350'**
  String get hd1080135030Fps;

  /// No description provided for @compact64080030Fps.
  ///
  /// In en, this message translates to:
  /// **'Compact · 640 × 800'**
  String get compact64080030Fps;

  /// No description provided for @exportMp4.
  ///
  /// In en, this message translates to:
  /// **'Export MP4'**
  String get exportMp4;

  /// No description provided for @shareExportedFile.
  ///
  /// In en, this message translates to:
  /// **'Share exported file'**
  String get shareExportedFile;

  /// No description provided for @saveAPublicCopy.
  ///
  /// In en, this message translates to:
  /// **'Save a public copy'**
  String get saveAPublicCopy;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @drawingCanvasHorizontalPositionControlsTimeHeightControlsP.
  ///
  /// In en, this message translates to:
  /// **'Drawing canvas. Horizontal position controls time; height controls pitch.'**
  String get drawingCanvasHorizontalPositionControlsTimeHeightControlsP;

  /// No description provided for @leaveALittleMelodyHere.
  ///
  /// In en, this message translates to:
  /// **'Leave a little melody here.'**
  String get leaveALittleMelodyHere;

  /// No description provided for @drawingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Drawing unavailable'**
  String get drawingUnavailable;

  /// No description provided for @couldNotOpenThisDrawingTheOriginalFileIsPreserved.
  ///
  /// In en, this message translates to:
  /// **'Could not open this drawing. The original file is preserved.'**
  String get couldNotOpenThisDrawingTheOriginalFileIsPreserved;

  /// No description provided for @backToDrafts.
  ///
  /// In en, this message translates to:
  /// **'Back to drafts'**
  String get backToDrafts;

  /// No description provided for @loopTempo.
  ///
  /// In en, this message translates to:
  /// **'Loop tempo'**
  String get loopTempo;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @yourLoopInNotes.
  ///
  /// In en, this message translates to:
  /// **'Your loop in notes'**
  String get yourLoopInNotes;

  /// No description provided for @clearThisDrawing.
  ///
  /// In en, this message translates to:
  /// **'Clear this drawing?'**
  String get clearThisDrawing;

  /// No description provided for @youCanRestoreItWithUndo.
  ///
  /// In en, this message translates to:
  /// **'You can restore it with Undo.'**
  String get youCanRestoreItWithUndo;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @backToGallery.
  ///
  /// In en, this message translates to:
  /// **'Back to gallery'**
  String get backToGallery;

  /// No description provided for @editorTips.
  ///
  /// In en, this message translates to:
  /// **'Editor tips'**
  String get editorTips;

  /// No description provided for @exportLoop.
  ///
  /// In en, this message translates to:
  /// **'Export loop'**
  String get exportLoop;

  /// No description provided for @saveDrawing.
  ///
  /// In en, this message translates to:
  /// **'Save drawing'**
  String get saveDrawing;

  /// No description provided for @recoveredThePreviousCompleteRevisionTheDamagedFileIsPreser.
  ///
  /// In en, this message translates to:
  /// **'Recovered the previous complete revision. The damaged file is preserved.'**
  String get recoveredThePreviousCompleteRevisionTheDamagedFileIsPreser;

  /// No description provided for @storageUnavailableRetryFromDraftsBeforeLeaving.
  ///
  /// In en, this message translates to:
  /// **'Storage unavailable. Retry from Drafts before leaving.'**
  String get storageUnavailableRetryFromDraftsBeforeLeaving;

  /// No description provided for @slower.
  ///
  /// In en, this message translates to:
  /// **'Slower'**
  String get slower;

  /// No description provided for @faster.
  ///
  /// In en, this message translates to:
  /// **'Faster'**
  String get faster;

  /// No description provided for @drawingStyle.
  ///
  /// In en, this message translates to:
  /// **'Drawing style'**
  String get drawingStyle;

  /// No description provided for @paperColor.
  ///
  /// In en, this message translates to:
  /// **'Paper color'**
  String get paperColor;

  /// No description provided for @clearDrawing.
  ///
  /// In en, this message translates to:
  /// **'Clear drawing'**
  String get clearDrawing;

  /// No description provided for @draw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get draw;

  /// No description provided for @erase.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get erase;

  /// No description provided for @describeScore.
  ///
  /// In en, this message translates to:
  /// **'Describe score'**
  String get describeScore;

  /// No description provided for @cMajorPentatonic.
  ///
  /// In en, this message translates to:
  /// **'C major pentatonic'**
  String get cMajorPentatonic;

  /// No description provided for @cMinorPentatonic.
  ///
  /// In en, this message translates to:
  /// **'C minor pentatonic'**
  String get cMinorPentatonic;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @replay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get replay;

  /// No description provided for @settingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Settings & help'**
  String get settingsHelp;

  /// No description provided for @retryPreferences.
  ///
  /// In en, this message translates to:
  /// **'Retry preferences'**
  String get retryPreferences;

  /// No description provided for @recoveredYourPreviousPreferencesYourDrawingsAreUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Recovered your previous preferences. Your drawings are unchanged.'**
  String get recoveredYourPreviousPreferencesYourDrawingsAreUnchanged;

  /// No description provided for @previewVolume.
  ///
  /// In en, this message translates to:
  /// **'Preview volume'**
  String get previewVolume;

  /// No description provided for @onlyChangesPlaybackInTheAppExportedMusicKeepsItsOriginalLe.
  ///
  /// In en, this message translates to:
  /// **'Only changes playback in the app. Exported music keeps its original level.'**
  String get onlyChangesPlaybackInTheAppExportedMusicKeepsItsOriginalLe;

  /// No description provided for @previewIsMutedExportsStillContainMusicAlsoCheckYourDeviceM.
  ///
  /// In en, this message translates to:
  /// **'Preview is muted. Exports still contain music. Also check your device media volume if playback is quiet.'**
  String get previewIsMutedExportsStillContainMusicAlsoCheckYourDeviceM;

  /// No description provided for @hapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get hapticFeedback;

  /// No description provided for @optionalFeedbackWhenChoosingAVoiceOrChangingTempoAvailabil.
  ///
  /// In en, this message translates to:
  /// **'Optional feedback when choosing a voice or changing tempo. Availability depends on your device.'**
  String get optionalFeedbackWhenChoosingAVoiceOrChangingTempoAvailabil;

  /// No description provided for @reduceNonessentialMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce nonessential motion'**
  String get reduceNonessentialMotion;

  /// No description provided for @turnOnToReducePageTransitionsWhenOffFollowsYourDevicePrefe.
  ///
  /// In en, this message translates to:
  /// **'Turn on to reduce page transitions. When off, follows your device preference. The music cursor remains available.'**
  String get turnOnToReducePageTransitionsWhenOffFollowsYourDevicePrefe;

  /// No description provided for @replayCreationGuide.
  ///
  /// In en, this message translates to:
  /// **'Replay creation guide'**
  String get replayCreationGuide;

  /// No description provided for @replayEditorTips.
  ///
  /// In en, this message translates to:
  /// **'Replay editor tips'**
  String get replayEditorTips;

  /// No description provided for @opensANewBlankDrawingWithGuidedControls.
  ///
  /// In en, this message translates to:
  /// **'Opens a new blank drawing with guided controls.'**
  String get opensANewBlankDrawingWithGuidedControls;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @drawingsPreferencesAndExportsStayOnThisDeviceCreationWorks.
  ///
  /// In en, this message translates to:
  /// **'Drawings, preferences and exports stay on this device. Creation works offline without an account. Files leave the app only when you explicitly share them. Uninstalling removes app-private data.'**
  String get drawingsPreferencesAndExportsStayOnThisDeviceCreationWorks;

  /// No description provided for @readingBuildInformation.
  ///
  /// In en, this message translates to:
  /// **'Reading build information…'**
  String get readingBuildInformation;

  /// No description provided for @buildInformationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Build information unavailable'**
  String get buildInformationUnavailable;

  /// No description provided for @tryAStartingPoint.
  ///
  /// In en, this message translates to:
  /// **'Try a starting point'**
  String get tryAStartingPoint;

  /// No description provided for @thisRemovesTheAppPrivateExportAfterTheUndoWindowCopiesSave.
  ///
  /// In en, this message translates to:
  /// **'This removes the app-private export after the Undo window. Copies saved or shared elsewhere stay. Your editable drawing is preserved.'**
  String get thisRemovesTheAppPrivateExportAfterTheUndoWindowCopiesSave;

  /// No description provided for @keepExport.
  ///
  /// In en, this message translates to:
  /// **'Keep export'**
  String get keepExport;

  /// No description provided for @exportRemovedFromTheLibrary.
  ///
  /// In en, this message translates to:
  /// **'Export removed from the library'**
  String get exportRemovedFromTheLibrary;

  /// No description provided for @yourExports.
  ///
  /// In en, this message translates to:
  /// **'Your exports'**
  String get yourExports;

  /// No description provided for @refreshExports.
  ///
  /// In en, this message translates to:
  /// **'Refresh exports'**
  String get refreshExports;

  /// No description provided for @couldNotLoadYourExports.
  ///
  /// In en, this message translates to:
  /// **'Could not load your exports.'**
  String get couldNotLoadYourExports;

  /// No description provided for @someExportDetailsCouldNotBeReadTheOriginalFilesArePreserve.
  ///
  /// In en, this message translates to:
  /// **'Some export details could not be read. The original files are preserved.'**
  String get someExportDetailsCouldNotBeReadTheOriginalFilesArePreserve;

  /// No description provided for @openWithAnotherApp.
  ///
  /// In en, this message translates to:
  /// **'Open with another app'**
  String get openWithAnotherApp;

  /// No description provided for @saveACopy.
  ///
  /// In en, this message translates to:
  /// **'Save a copy'**
  String get saveACopy;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @openSourceDrawing.
  ///
  /// In en, this message translates to:
  /// **'Open source drawing'**
  String get openSourceDrawing;

  /// No description provided for @paperPreview.
  ///
  /// In en, this message translates to:
  /// **'Paper preview'**
  String get paperPreview;

  /// No description provided for @opacityFadesThePaperColorTowardWhiteYourMarksAndMusicStayT.
  ///
  /// In en, this message translates to:
  /// **'Opacity fades the paper color toward white. Your marks and music stay the same.'**
  String get opacityFadesThePaperColorTowardWhiteYourMarksAndMusicStayT;

  /// No description provided for @stylesChangeHowYourMarksLookOriginalPointsAndMusicArePrese.
  ///
  /// In en, this message translates to:
  /// **'Styles change how your marks look. Original points and music are preserved.'**
  String get stylesChangeHowYourMarksLookOriginalPointsAndMusicArePrese;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @languageSelectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get languageSelectorTitle;

  /// No description provided for @languageSaved.
  ///
  /// In en, this message translates to:
  /// **'Language saved'**
  String get languageSaved;

  /// No description provided for @languageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save language. Retry from Settings.'**
  String get languageSaveFailed;

  /// No description provided for @languageExplanation.
  ///
  /// In en, this message translates to:
  /// **'Choose a language, then Apply. Your drawing titles stay unchanged.'**
  String get languageExplanation;

  /// No description provided for @updatedOn.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String updatedOn(String date);

  /// No description provided for @tempoValue.
  ///
  /// In en, this message translates to:
  /// **'{tempo} BPM'**
  String tempoValue(String tempo);

  /// No description provided for @sizeKilobytes.
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String sizeKilobytes(String size);

  /// No description provided for @drawAMelody.
  ///
  /// In en, this message translates to:
  /// **'Draw a melody'**
  String get drawAMelody;

  /// No description provided for @leftToRightFollowsEightBeatsHigherMarksMakeHigherNotesVert.
  ///
  /// In en, this message translates to:
  /// **'Left to right follows eight beats. Higher marks make higher notes; vertical marks can form chords. Erase and Undo let you explore safely.'**
  String get leftToRightFollowsEightBeatsHigherMarksMakeHigherNotesVert;

  /// No description provided for @listenAndPause.
  ///
  /// In en, this message translates to:
  /// **'Listen and pause'**
  String get listenAndPause;

  /// No description provided for @playRepeatsYourDrawingTapPauseToKeepYourPlaceOrReplayToSta.
  ///
  /// In en, this message translates to:
  /// **'Play repeats your drawing. Tap Pause to keep your place, or Replay to start over. Music pauses when you leave the app.'**
  String get playRepeatsYourDrawingTapPauseToKeepYourPlaceOrReplayToSta;

  /// No description provided for @cloudKeysWoodDropsAndGlassStarsAreNamedOriginalInstruments.
  ///
  /// In en, this message translates to:
  /// **'Cloud keys, Wood drops and Glass stars are named original instruments. Each new stroke uses the selected voice; existing strokes keep theirs.'**
  String get cloudKeysWoodDropsAndGlassStarsAreNamedOriginalInstruments;

  /// No description provided for @setThePace.
  ///
  /// In en, this message translates to:
  /// **'Set the pace'**
  String get setThePace;

  /// No description provided for @tapTheBpmNumberForTheTempoSliderHoldMinusOrPlusToRepeatFro.
  ///
  /// In en, this message translates to:
  /// **'Tap the BPM number for the tempo slider. Hold minus or plus to repeat, from 60 to 200 BPM. Tempo updates arrive on a beat; drawing updates arrive on a loop.'**
  String get tapTheBpmNumberForTheTempoSliderHoldMinusOrPlusToRepeatFro;

  /// No description provided for @keyAndScale.
  ///
  /// In en, this message translates to:
  /// **'Key and scale'**
  String get keyAndScale;

  /// No description provided for @thisVersionUsesTheKeyOfCChooseMajorOrMinorPentatonicHereTo.
  ///
  /// In en, this message translates to:
  /// **'Choose any root key and scale to change the mood. The same score drives preview and exports.'**
  String get thisVersionUsesTheKeyOfCChooseMajorOrMinorPentatonicHereTo;

  /// No description provided for @warmPaper.
  ///
  /// In en, this message translates to:
  /// **'Warm paper'**
  String get warmPaper;

  /// No description provided for @mintPaper.
  ///
  /// In en, this message translates to:
  /// **'Mint paper'**
  String get mintPaper;

  /// No description provided for @lilacPaper.
  ///
  /// In en, this message translates to:
  /// **'Lilac paper'**
  String get lilacPaper;

  /// No description provided for @rosePaper.
  ///
  /// In en, this message translates to:
  /// **'Rose paper'**
  String get rosePaper;

  /// No description provided for @drawingDetails.
  ///
  /// In en, this message translates to:
  /// **'{marks} marks · {tempo} BPM · {root} {scale}'**
  String drawingDetails(String root, String marks, String tempo, String scale);

  /// No description provided for @exportDetails.
  ///
  /// In en, this message translates to:
  /// **'{format} · {date} · {size} KB'**
  String exportDetails(String format, String date, String size);

  /// No description provided for @manageDrawing.
  ///
  /// In en, this message translates to:
  /// **'Manage {title}'**
  String manageDrawing(String title);

  /// No description provided for @renameDrawingLabel.
  ///
  /// In en, this message translates to:
  /// **'Rename drawing, {title}'**
  String renameDrawingLabel(String title);

  /// No description provided for @exportActions.
  ///
  /// In en, this message translates to:
  /// **'Actions for {name}'**
  String exportActions(String name);

  /// No description provided for @paperOpacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity {value}%'**
  String paperOpacity(String value);

  /// No description provided for @paperOpacitySemantics.
  ///
  /// In en, this message translates to:
  /// **'Paper opacity {value} percent'**
  String paperOpacitySemantics(String value);

  /// No description provided for @percentValue.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String percentValue(String value);

  /// No description provided for @major.
  ///
  /// In en, this message translates to:
  /// **'major'**
  String get major;

  /// No description provided for @minor.
  ///
  /// In en, this message translates to:
  /// **'minor'**
  String get minor;

  /// No description provided for @recoveredPreviousRevision.
  ///
  /// In en, this message translates to:
  /// **'Recovered previous revision'**
  String get recoveredPreviousRevision;

  /// No description provided for @fileUnavailableExportAgain.
  ///
  /// In en, this message translates to:
  /// **'File unavailable — export again from the drawing'**
  String get fileUnavailableExportAgain;

  /// No description provided for @olderExportSourceDetailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Older export — source details unavailable'**
  String get olderExportSourceDetailsUnavailable;

  /// No description provided for @drawingMayHaveChangedSinceExport.
  ///
  /// In en, this message translates to:
  /// **'Drawing may have changed since this export'**
  String get drawingMayHaveChangedSinceExport;

  /// No description provided for @smoothStyleSelected.
  ///
  /// In en, this message translates to:
  /// **'Smooth drawing style selected'**
  String get smoothStyleSelected;

  /// No description provided for @pixelStyleSelected.
  ///
  /// In en, this message translates to:
  /// **'Pixel drawing style selected'**
  String get pixelStyleSelected;

  /// No description provided for @updatesNextBeat.
  ///
  /// In en, this message translates to:
  /// **'Updates next beat'**
  String get updatesNextBeat;

  /// No description provided for @updatesNextLoop.
  ///
  /// In en, this message translates to:
  /// **'Updates next loop'**
  String get updatesNextLoop;

  /// No description provided for @drawSomethingToHearIt.
  ///
  /// In en, this message translates to:
  /// **'Draw something to hear it.'**
  String get drawSomethingToHearIt;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @changesPending.
  ///
  /// In en, this message translates to:
  /// **'Changes pending'**
  String get changesPending;

  /// No description provided for @savedOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device'**
  String get savedOnThisDevice;

  /// No description provided for @oneLoopExportSummary.
  ///
  /// In en, this message translates to:
  /// **'One loop · {seconds} seconds. Exports use the drawing and settings shown when this panel opened.'**
  String oneLoopExportSummary(String seconds);

  /// No description provided for @wavExportSummary.
  ///
  /// In en, this message translates to:
  /// **'WAV uses the original preview voices. One loop + 1.25 s tail, 44.1 kHz mono PCM16 (~{kilobytes} KB).'**
  String wavExportSummary(String kilobytes);

  /// No description provided for @scoreSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} note events · {tempo} BPM · {root} {scale}'**
  String scoreSummary(String root, String count, String tempo, String scale);

  /// No description provided for @scoreEvent.
  ///
  /// In en, this message translates to:
  /// **'{voice}: MIDI pitch {pitch}, beat {beat}, lasts {duration} beats.'**
  String scoreEvent(String voice, String pitch, String beat, String duration);

  /// No description provided for @tipCounter.
  ///
  /// In en, this message translates to:
  /// **'Tip {current} of {total}'**
  String tipCounter(String current, String total);

  /// No description provided for @cloudKeys.
  ///
  /// In en, this message translates to:
  /// **'Cloud keys'**
  String get cloudKeys;

  /// No description provided for @woodDrops.
  ///
  /// In en, this message translates to:
  /// **'Wood drops'**
  String get woodDrops;

  /// No description provided for @glassStars.
  ///
  /// In en, this message translates to:
  /// **'Glass stars'**
  String get glassStars;

  /// No description provided for @smooth.
  ///
  /// In en, this message translates to:
  /// **'Smooth'**
  String get smooth;

  /// No description provided for @pixel.
  ///
  /// In en, this message translates to:
  /// **'Pixel'**
  String get pixel;

  /// No description provided for @originalFreehandLines.
  ///
  /// In en, this message translates to:
  /// **'Original freehand lines'**
  String get originalFreehandLines;

  /// No description provided for @blockShapesOnGrid.
  ///
  /// In en, this message translates to:
  /// **'Block shapes on a 40 × 50 grid'**
  String get blockShapesOnGrid;

  /// No description provided for @finishingLibraryEntry.
  ///
  /// In en, this message translates to:
  /// **'Finishing library entry…'**
  String get finishingLibraryEntry;

  /// No description provided for @cancelExport.
  ///
  /// In en, this message translates to:
  /// **'Cancel export'**
  String get cancelExport;

  /// No description provided for @showingFirst80Events.
  ///
  /// In en, this message translates to:
  /// **'Showing the first 80 events.'**
  String get showingFirst80Events;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @creationGuide.
  ///
  /// In en, this message translates to:
  /// **'Creation guide'**
  String get creationGuide;

  /// No description provided for @welcomeToScribbleSong.
  ///
  /// In en, this message translates to:
  /// **'Welcome to ScribbleSong'**
  String get welcomeToScribbleSong;

  /// No description provided for @howToCreateALoop.
  ///
  /// In en, this message translates to:
  /// **'How to create a loop'**
  String get howToCreateALoop;

  /// No description provided for @pressAndHoldToRepeat.
  ///
  /// In en, this message translates to:
  /// **'Press and hold to repeat'**
  String get pressAndHoldToRepeat;

  /// No description provided for @preferencesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load preferences. Your drawings are safe. Retry or continue for now.'**
  String get preferencesLoadFailed;

  /// No description provided for @preferencesSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save preferences. Check storage, then retry.'**
  String get preferencesSaveFailed;

  /// No description provided for @drawingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save this drawing. Check device storage, then retry.'**
  String get drawingSaveFailed;

  /// No description provided for @drawingSaveRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not save this drawing. Check device storage, then retry Save.'**
  String get drawingSaveRetry;

  /// No description provided for @playbackUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not play. Check your audio output and try again.'**
  String get playbackUnavailable;

  /// No description provided for @playbackUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update playback. Your drawing is safe. Try Play again.'**
  String get playbackUpdateFailed;

  /// No description provided for @playbackStopped.
  ///
  /// In en, this message translates to:
  /// **'Playback stopped. Please retry.'**
  String get playbackStopped;

  /// No description provided for @scoreTooComplex.
  ///
  /// In en, this message translates to:
  /// **'This drawing has too many overlapping notes. Erase a few marks and try again (32 voices / 4096 notes).'**
  String get scoreTooComplex;

  /// No description provided for @tipsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Tips closed for now. Completion could not be saved; retry from Settings or replay Editor tips.'**
  String get tipsSaveFailed;

  /// No description provided for @leaveSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save did not complete. Stay here and retry Save before leaving.'**
  String get leaveSaveFailed;

  /// No description provided for @exportReady.
  ///
  /// In en, this message translates to:
  /// **'Export ready on this device.'**
  String get exportReady;

  /// No description provided for @exportDetailsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Export created. Library details could not be saved; the file is preserved under Library → Exports.'**
  String get exportDetailsSaveFailed;

  /// No description provided for @exportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export canceled. Your drawing is safe.'**
  String get exportCancelled;

  /// No description provided for @videoExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Video export failed. Try compact resolution or check storage, then retry.'**
  String get videoExportFailed;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed. Check storage and retry.'**
  String get exportFailed;

  /// No description provided for @shareDismissed.
  ///
  /// In en, this message translates to:
  /// **'Share sheet dismissed. Export is still saved.'**
  String get shareDismissed;

  /// No description provided for @shareClosed.
  ///
  /// In en, this message translates to:
  /// **'Share sheet closed. Delivery is handled by the selected app.'**
  String get shareClosed;

  /// No description provided for @shareUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sharing unavailable. The exported file is still saved.'**
  String get shareUnavailable;

  /// No description provided for @publicSaveCancelled.
  ///
  /// In en, this message translates to:
  /// **'Save canceled. Your export is still saved on this device.'**
  String get publicSaveCancelled;

  /// No description provided for @publicSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save a public copy. Check storage and retry. Your export is preserved.'**
  String get publicSaveFailed;

  /// No description provided for @librarySaveCancelled.
  ///
  /// In en, this message translates to:
  /// **'Save canceled. Your export is still in the library.'**
  String get librarySaveCancelled;

  /// No description provided for @libraryPublicSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save a public copy. Check storage and retry. The library file is preserved.'**
  String get libraryPublicSaveFailed;

  /// No description provided for @libraryShareUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sharing unavailable. The library file is preserved.'**
  String get libraryShareUnavailable;

  /// No description provided for @exportRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore this export. Open the drawing to export again.'**
  String get exportRestoreFailed;

  /// No description provided for @exportOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this export. A compatible app may be unavailable. Try sharing it.'**
  String get exportOpenFailed;

  /// No description provided for @exportChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change this export. Please retry.'**
  String get exportChangeFailed;

  /// No description provided for @exportsUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Some exports could not be read. Their files are preserved. Try Refresh exports.'**
  String get exportsUnreadable;

  /// No description provided for @exportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Completed exports will appear here.\nOpen a drawing and choose Export to create MIDI, WAV, MP4 or PNG.'**
  String get exportsEmpty;

  /// No description provided for @nameYourExport.
  ///
  /// In en, this message translates to:
  /// **'Name your export'**
  String get nameYourExport;

  /// No description provided for @nameYourDrawing.
  ///
  /// In en, this message translates to:
  /// **'Name your drawing'**
  String get nameYourDrawing;

  /// No description provided for @nameLengthError.
  ///
  /// In en, this message translates to:
  /// **'Use a name of 1–60 characters'**
  String get nameLengthError;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @startCreating.
  ///
  /// In en, this message translates to:
  /// **'Start creating'**
  String get startCreating;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @nextTip.
  ///
  /// In en, this message translates to:
  /// **'Next tip'**
  String get nextTip;

  /// No description provided for @damagedDrawing.
  ///
  /// In en, this message translates to:
  /// **'damaged drawing'**
  String get damagedDrawing;

  /// No description provided for @savedPublicCopy.
  ///
  /// In en, this message translates to:
  /// **'Saved a copy to {destination}.'**
  String savedPublicCopy(String destination);

  /// No description provided for @savedNamedPublicCopy.
  ///
  /// In en, this message translates to:
  /// **'Saved {name} to {destination}.'**
  String savedNamedPublicCopy(String name, String destination);

  /// No description provided for @deleteNamedItem.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteNamedItem(String name);

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String appVersion(String version, String build);

  /// No description provided for @previewVolumePercent.
  ///
  /// In en, this message translates to:
  /// **'{value} percent preview volume'**
  String previewVolumePercent(String value);

  /// No description provided for @drawingPointLimit.
  ///
  /// In en, this message translates to:
  /// **'100,000 point limit reached. Save this drawing and start a new one.'**
  String get drawingPointLimit;

  /// No description provided for @scoreDescriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not describe this loop. Your drawing is safe. Please retry.'**
  String get scoreDescriptionFailed;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @exportPng.
  ///
  /// In en, this message translates to:
  /// **'Export PNG'**
  String get exportPng;

  /// No description provided for @pngExportDescription.
  ///
  /// In en, this message translates to:
  /// **'Save the drawing as an image without controls or playback cursor.'**
  String get pngExportDescription;

  /// No description provided for @transparentBackground.
  ///
  /// In en, this message translates to:
  /// **'Transparent background'**
  String get transparentBackground;

  /// No description provided for @pngOutputSize.
  ///
  /// In en, this message translates to:
  /// **'PNG image size'**
  String get pngOutputSize;

  /// No description provided for @pngHd.
  ///
  /// In en, this message translates to:
  /// **'HD · 1080 × 1350'**
  String get pngHd;

  /// No description provided for @pngCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact · 640 × 800'**
  String get pngCompact;

  /// No description provided for @rootKey.
  ///
  /// In en, this message translates to:
  /// **'Root key'**
  String get rootKey;

  /// No description provided for @scaleFamily.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get scaleFamily;

  /// No description provided for @majorPentatonic.
  ///
  /// In en, this message translates to:
  /// **'Major pentatonic'**
  String get majorPentatonic;

  /// No description provided for @minorPentatonic.
  ///
  /// In en, this message translates to:
  /// **'Minor pentatonic'**
  String get minorPentatonic;

  /// No description provided for @diatonicMajor.
  ///
  /// In en, this message translates to:
  /// **'Major'**
  String get diatonicMajor;

  /// No description provided for @diatonicMinor.
  ///
  /// In en, this message translates to:
  /// **'Minor'**
  String get diatonicMinor;

  /// No description provided for @harmonicMinor.
  ///
  /// In en, this message translates to:
  /// **'Harmonic minor'**
  String get harmonicMinor;

  /// No description provided for @dorian.
  ///
  /// In en, this message translates to:
  /// **'Dorian'**
  String get dorian;

  /// No description provided for @phrygian.
  ///
  /// In en, this message translates to:
  /// **'Phrygian'**
  String get phrygian;

  /// No description provided for @lydian.
  ///
  /// In en, this message translates to:
  /// **'Lydian'**
  String get lydian;

  /// No description provided for @mixolydian.
  ///
  /// In en, this message translates to:
  /// **'Mixolydian'**
  String get mixolydian;

  /// No description provided for @blues.
  ///
  /// In en, this message translates to:
  /// **'Blues'**
  String get blues;

  /// No description provided for @chromatic.
  ///
  /// In en, this message translates to:
  /// **'Chromatic'**
  String get chromatic;

  /// No description provided for @warmSynth.
  ///
  /// In en, this message translates to:
  /// **'Amber pad'**
  String get warmSynth;

  /// No description provided for @pluck.
  ///
  /// In en, this message translates to:
  /// **'Dew pluck'**
  String get pluck;

  /// No description provided for @flute.
  ///
  /// In en, this message translates to:
  /// **'Reed breeze'**
  String get flute;

  /// No description provided for @strings.
  ///
  /// In en, this message translates to:
  /// **'Velvet strings'**
  String get strings;

  /// No description provided for @chime.
  ///
  /// In en, this message translates to:
  /// **'Silver chime'**
  String get chime;

  /// No description provided for @bass.
  ///
  /// In en, this message translates to:
  /// **'Earth bass'**
  String get bass;

  /// No description provided for @chip.
  ///
  /// In en, this message translates to:
  /// **'Pocket chip'**
  String get chip;

  /// No description provided for @electronicBass.
  ///
  /// In en, this message translates to:
  /// **'Neon bass'**
  String get electronicBass;

  /// No description provided for @guitar.
  ///
  /// In en, this message translates to:
  /// **'Cedar guitar'**
  String get guitar;

  /// No description provided for @saxophone.
  ///
  /// In en, this message translates to:
  /// **'Copper reed'**
  String get saxophone;

  /// No description provided for @geometrySimplified.
  ///
  /// In en, this message translates to:
  /// **'Dense points were simplified within the documented tolerance. Undo restores the original drawing.'**
  String get geometrySimplified;

  /// No description provided for @compatibilityFallback.
  ///
  /// In en, this message translates to:
  /// **'Some saved sounds or scales are unavailable. A safe substitute is used; original identifiers are preserved.'**
  String get compatibilityFallback;

  /// No description provided for @backgroundType.
  ///
  /// In en, this message translates to:
  /// **'Background type'**
  String get backgroundType;

  /// No description provided for @solidBackground.
  ///
  /// In en, this message translates to:
  /// **'Solid color'**
  String get solidBackground;

  /// No description provided for @linearBackground.
  ///
  /// In en, this message translates to:
  /// **'Linear gradient'**
  String get linearBackground;

  /// No description provided for @radialBackground.
  ///
  /// In en, this message translates to:
  /// **'Radial gradient'**
  String get radialBackground;

  /// No description provided for @photoBackground.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photoBackground;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom color (RRGGBB)'**
  String get customColor;

  /// No description provided for @secondColor.
  ///
  /// In en, this message translates to:
  /// **'Second color (RRGGBB)'**
  String get secondColor;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get choosePhoto;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @replacePhoto.
  ///
  /// In en, this message translates to:
  /// **'Replace photo'**
  String get replacePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @rotatePhoto.
  ///
  /// In en, this message translates to:
  /// **'Rotate photo'**
  String get rotatePhoto;

  /// No description provided for @mirrorPhoto.
  ///
  /// In en, this message translates to:
  /// **'Mirror photo'**
  String get mirrorPhoto;

  /// No description provided for @cropLeft.
  ///
  /// In en, this message translates to:
  /// **'Crop left'**
  String get cropLeft;

  /// No description provided for @cropTop.
  ///
  /// In en, this message translates to:
  /// **'Crop top'**
  String get cropTop;

  /// No description provided for @cropWidth.
  ///
  /// In en, this message translates to:
  /// **'Crop width'**
  String get cropWidth;

  /// No description provided for @cropHeight.
  ///
  /// In en, this message translates to:
  /// **'Crop height'**
  String get cropHeight;

  /// No description provided for @imageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This photo is unavailable. Replace or remove it.'**
  String get imageUnavailable;

  /// No description provided for @imageImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import this image. Choose a valid JPEG, PNG or supported HEIC image under 32 MB.'**
  String get imageImportFailed;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No camera app is available. You can choose a photo instead.'**
  String get cameraUnavailable;

  /// No description provided for @photoPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Photo access was denied. Choose another image or check system permissions.'**
  String get photoPermissionDenied;

  /// No description provided for @backgroundImportBusy.
  ///
  /// In en, this message translates to:
  /// **'Importing image…'**
  String get backgroundImportBusy;

  /// No description provided for @backgroundRecovered.
  ///
  /// In en, this message translates to:
  /// **'Recovered your interrupted photo selection.'**
  String get backgroundRecovered;

  /// No description provided for @resetCrop.
  ///
  /// In en, this message translates to:
  /// **'Reset crop'**
  String get resetCrop;

  /// No description provided for @backgroundGradientTip.
  ///
  /// In en, this message translates to:
  /// **'Backgrounds change the picture only; your notes stay the same.'**
  String get backgroundGradientTip;

  /// No description provided for @gradientDawn.
  ///
  /// In en, this message translates to:
  /// **'Dawn gradient'**
  String get gradientDawn;

  /// No description provided for @gradientOrchard.
  ///
  /// In en, this message translates to:
  /// **'Orchard gradient'**
  String get gradientOrchard;

  /// No description provided for @gradientTwilight.
  ///
  /// In en, this message translates to:
  /// **'Twilight gradient'**
  String get gradientTwilight;

  /// No description provided for @accompaniment.
  ///
  /// In en, this message translates to:
  /// **'Accompaniment'**
  String get accompaniment;

  /// No description provided for @drumKit.
  ///
  /// In en, this message translates to:
  /// **'Drum kit'**
  String get drumKit;

  /// No description provided for @arpeggio.
  ///
  /// In en, this message translates to:
  /// **'Arpeggio'**
  String get arpeggio;

  /// No description provided for @kick.
  ///
  /// In en, this message translates to:
  /// **'Kick'**
  String get kick;

  /// No description provided for @snare.
  ///
  /// In en, this message translates to:
  /// **'Snare'**
  String get snare;

  /// No description provided for @clap.
  ///
  /// In en, this message translates to:
  /// **'Clap'**
  String get clap;

  /// No description provided for @hiHat.
  ///
  /// In en, this message translates to:
  /// **'Hi-hat'**
  String get hiHat;

  /// No description provided for @muted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get muted;

  /// No description provided for @layerLevel.
  ///
  /// In en, this message translates to:
  /// **'Layer level'**
  String get layerLevel;

  /// No description provided for @expressiveMode.
  ///
  /// In en, this message translates to:
  /// **'Expressive dynamics'**
  String get expressiveMode;

  /// No description provided for @expressiveModeHelp.
  ///
  /// In en, this message translates to:
  /// **'Use recorded gesture speed for note dynamics. Geometry mode stays independent of drawing speed.'**
  String get expressiveModeHelp;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get darkTheme;

  /// No description provided for @useSystemTheme.
  ///
  /// In en, this message translates to:
  /// **'Use system theme'**
  String get useSystemTheme;

  /// No description provided for @pngEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Export an empty drawing?'**
  String get pngEmptyTitle;

  /// No description provided for @pngEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'This image will contain only the background, or be transparent when that option is selected.'**
  String get pngEmptyDescription;

  /// No description provided for @videoFrameRate.
  ///
  /// In en, this message translates to:
  /// **'Video frame rate'**
  String get videoFrameRate;

  /// No description provided for @videoFps30.
  ///
  /// In en, this message translates to:
  /// **'30 FPS — standard'**
  String get videoFps30;

  /// No description provided for @videoFps60.
  ///
  /// In en, this message translates to:
  /// **'60 FPS — smoother, slower export'**
  String get videoFps60;

  /// No description provided for @reviewOptionalTitle.
  ///
  /// In en, this message translates to:
  /// **'Optional app review'**
  String get reviewOptionalTitle;

  /// No description provided for @reviewOptionalBody.
  ///
  /// In en, this message translates to:
  /// **'Your work is saved. Your device may show a review sheet, which you can close without submitting a review.'**
  String get reviewOptionalBody;

  /// No description provided for @reviewNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get reviewNotNow;

  /// No description provided for @reviewContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get reviewContinue;

  /// No description provided for @muteLayer.
  ///
  /// In en, this message translates to:
  /// **'Mute layer'**
  String get muteLayer;

  /// No description provided for @unmuteLayer.
  ///
  /// In en, this message translates to:
  /// **'Unmute layer'**
  String get unmuteLayer;

  /// No description provided for @templateDescription0.
  ///
  /// In en, this message translates to:
  /// **'Two rising peaks on a mallet voice.'**
  String get templateDescription0;

  /// No description provided for @templateDescription1.
  ///
  /// In en, this message translates to:
  /// **'Falling bell lines form vertical chords.'**
  String get templateDescription1;

  /// No description provided for @templateDescription2.
  ///
  /// In en, this message translates to:
  /// **'A smooth keyboard wave explores pitch.'**
  String get templateDescription2;

  /// No description provided for @templateDescription3.
  ///
  /// In en, this message translates to:
  /// **'Eight isolated mallet dots make a rhythm.'**
  String get templateDescription3;

  /// No description provided for @templateDescription4.
  ///
  /// In en, this message translates to:
  /// **'A bell ellipse meets the scan twice.'**
  String get templateDescription4;

  /// No description provided for @templateDescription5.
  ///
  /// In en, this message translates to:
  /// **'Three original voices travel side by side.'**
  String get templateDescription5;

  /// No description provided for @templateDescription6.
  ///
  /// In en, this message translates to:
  /// **'Ascending plucked steps leave breathing gaps.'**
  String get templateDescription6;

  /// No description provided for @templateDescription7.
  ///
  /// In en, this message translates to:
  /// **'Four flute chords at spaced times.'**
  String get templateDescription7;

  /// No description provided for @templateDescription8.
  ///
  /// In en, this message translates to:
  /// **'A broad string wave changes direction.'**
  String get templateDescription8;

  /// No description provided for @templateDescription9.
  ///
  /// In en, this message translates to:
  /// **'Separate chime dots make a short pattern.'**
  String get templateDescription9;

  /// No description provided for @templateDescription10.
  ///
  /// In en, this message translates to:
  /// **'A low-voice ellipse is a beginner loop.'**
  String get templateDescription10;

  /// No description provided for @templateDescription11.
  ///
  /// In en, this message translates to:
  /// **'Guitar, reed and keyboard ribbons interweave.'**
  String get templateDescription11;

  /// No description provided for @templateDescription12.
  ///
  /// In en, this message translates to:
  /// **'Electronic bass steps climb through the scale.'**
  String get templateDescription12;

  /// No description provided for @templateDescription13.
  ///
  /// In en, this message translates to:
  /// **'Guitar chords make four vertical windows.'**
  String get templateDescription13;

  /// No description provided for @templateDescription14.
  ///
  /// In en, this message translates to:
  /// **'A reed wave meanders across the page.'**
  String get templateDescription14;

  /// No description provided for @templateDescription15.
  ///
  /// In en, this message translates to:
  /// **'Keyboard dots leave generous silence.'**
  String get templateDescription15;

  /// No description provided for @templateDescription16.
  ///
  /// In en, this message translates to:
  /// **'A mallet ring demonstrates two pitch paths.'**
  String get templateDescription16;

  /// No description provided for @templateDescription17.
  ///
  /// In en, this message translates to:
  /// **'Three voices with original bass and drum accompaniment.'**
  String get templateDescription17;

  /// No description provided for @templateDescription18.
  ///
  /// In en, this message translates to:
  /// **'Bell steps rise through the scale.'**
  String get templateDescription18;

  /// No description provided for @templateDescription19.
  ///
  /// In en, this message translates to:
  /// **'Four warm synthesizer chords with bass and drum accompaniment.'**
  String get templateDescription19;

  /// No description provided for @recoveryExport.
  ///
  /// In en, this message translates to:
  /// **'Export recovery data'**
  String get recoveryExport;

  /// No description provided for @recoveryExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export recovery data. The original files are preserved.'**
  String get recoveryExportFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'en',
    'es',
    'fil',
    'fr',
    'hi',
    'id',
    'it',
    'ja',
    'ko',
    'pt',
    'th',
    'vi',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fil':
      return AppLocalizationsFil();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'th':
      return AppLocalizationsTh();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
