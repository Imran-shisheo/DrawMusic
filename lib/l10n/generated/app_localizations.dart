import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

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
  /// **'HD · 1080 × 1350 · 30 fps'**
  String get hd1080135030Fps;

  /// No description provided for @compact64080030Fps.
  ///
  /// In en, this message translates to:
  /// **'Compact · 640 × 800 · 30 fps'**
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
  /// **'English is currently available.'**
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
  /// **'This version uses the key of C. Choose major or minor pentatonic here to change the mood. The same score drives preview and exports.'**
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
  /// **'{marks} marks · {tempo} BPM · C {scale}'**
  String drawingDetails(String marks, String tempo, String scale);

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
  /// **'{count} note events · {tempo} BPM · C {scale} pentatonic.'**
  String scoreSummary(String count, String tempo, String scale);

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
  /// **'Completed exports will appear here.\nOpen a drawing and choose Export to create MIDI, WAV or MP4.'**
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
