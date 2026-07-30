import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
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
    Locale('de'),
    Locale('en'),
  ];

  /// The title of the application, shown e.g. in the OS task switcher.
  ///
  /// In en, this message translates to:
  /// **'Fleuron'**
  String get appTitle;

  /// Title of the language switcher dialog and its menu entry.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Option that makes the app follow the device's system language.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @userSwitchDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Who\'s using this phone?'**
  String get userSwitchDialogTitle;

  /// No description provided for @holidaySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Country & Holidays'**
  String get holidaySettingsTitle;

  /// No description provided for @holidaySettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose which holidays should be marked in the calendar.'**
  String get holidaySettingsDescription;

  /// No description provided for @countryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryLabel;

  /// No description provided for @regionLabel.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get regionLabel;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @countryGermany.
  ///
  /// In en, this message translates to:
  /// **'Germany'**
  String get countryGermany;

  /// No description provided for @countryAustria.
  ///
  /// In en, this message translates to:
  /// **'Austria'**
  String get countryAustria;

  /// No description provided for @countrySwitzerland.
  ///
  /// In en, this message translates to:
  /// **'Switzerland'**
  String get countrySwitzerland;

  /// No description provided for @regionNone.
  ///
  /// In en, this message translates to:
  /// **'No specific region'**
  String get regionNone;

  /// No description provided for @deleteRecurringEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete recurring event'**
  String get deleteRecurringEventTitle;

  /// No description provided for @deleteRecurringEventMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete only this occurrence or the entire series?'**
  String get deleteRecurringEventMessage;

  /// No description provided for @deleteThisOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Only this occurrence'**
  String get deleteThisOccurrence;

  /// No description provided for @deleteEntireSeries.
  ///
  /// In en, this message translates to:
  /// **'Entire series'**
  String get deleteEntireSeries;

  /// No description provided for @searchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTooltip;

  /// No description provided for @viewSelectorTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select view'**
  String get viewSelectorTooltip;

  /// No description provided for @todayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTooltip;

  /// No description provided for @viewMonth.
  ///
  /// In en, this message translates to:
  /// **'Month view'**
  String get viewMonth;

  /// No description provided for @viewTwoWeeks.
  ///
  /// In en, this message translates to:
  /// **'14 days'**
  String get viewTwoWeeks;

  /// No description provided for @viewWeek.
  ///
  /// In en, this message translates to:
  /// **'Week view'**
  String get viewWeek;

  /// No description provided for @newEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get newEvent;

  /// No description provided for @todos.
  ///
  /// In en, this message translates to:
  /// **'To-dos'**
  String get todos;

  /// No description provided for @shoppingList.
  ///
  /// In en, this message translates to:
  /// **'Shopping list'**
  String get shoppingList;

  /// No description provided for @noEvents.
  ///
  /// In en, this message translates to:
  /// **'No events'**
  String get noEvents;

  /// No description provided for @allDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get allDay;

  /// No description provided for @allDayShort.
  ///
  /// In en, this message translates to:
  /// **'All\nday'**
  String get allDayShort;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @activeProfile.
  ///
  /// In en, this message translates to:
  /// **'Active profile'**
  String get activeProfile;

  /// No description provided for @sectionView.
  ///
  /// In en, this message translates to:
  /// **'VIEW'**
  String get sectionView;

  /// No description provided for @grayOutPastEventsLabel.
  ///
  /// In en, this message translates to:
  /// **'Gray out past events'**
  String get grayOutPastEventsLabel;

  /// No description provided for @weekNumbersLabel.
  ///
  /// In en, this message translates to:
  /// **'Week numbers'**
  String get weekNumbersLabel;

  /// No description provided for @showHolidaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Show holidays'**
  String get showHolidaysLabel;

  /// No description provided for @sectionSettings.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get sectionSettings;

  /// No description provided for @teamAndGroups.
  ///
  /// In en, this message translates to:
  /// **'Team & groups'**
  String get teamAndGroups;

  /// No description provided for @addPeople.
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get addPeople;

  /// No description provided for @teamColors.
  ///
  /// In en, this message translates to:
  /// **'Team colors (groups)'**
  String get teamColors;

  /// No description provided for @assignFolders.
  ///
  /// In en, this message translates to:
  /// **'Assign folders'**
  String get assignFolders;

  /// No description provided for @workspacesAndAccounts.
  ///
  /// In en, this message translates to:
  /// **'Workspaces & accounts'**
  String get workspacesAndAccounts;

  /// No description provided for @teamSyncManual.
  ///
  /// In en, this message translates to:
  /// **'Team sync (manual)'**
  String get teamSyncManual;

  /// No description provided for @helpAndGuide.
  ///
  /// In en, this message translates to:
  /// **'Guide & help'**
  String get helpAndGuide;

  /// No description provided for @readOnlyCalendarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read-only calendar'**
  String get readOnlyCalendarSubtitle;

  /// No description provided for @caldavWorkspaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'CalDAV workspace'**
  String get caldavWorkspaceSubtitle;

  /// No description provided for @newWorkspace.
  ///
  /// In en, this message translates to:
  /// **'New workspace'**
  String get newWorkspace;

  /// No description provided for @noWorkspacesTitle.
  ///
  /// In en, this message translates to:
  /// **'No workspaces yet'**
  String get noWorkspacesTitle;

  /// No description provided for @noWorkspacesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a separate workspace for\neach family or organization.'**
  String get noWorkspacesSubtitle;

  /// No description provided for @newWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Create new workspace'**
  String get newWorkspaceTitle;

  /// No description provided for @editWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit workspace'**
  String get editWorkspaceTitle;

  /// No description provided for @activateWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Activate workspace'**
  String get activateWorkspace;

  /// No description provided for @activateWorkspaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Makes this area visible in the app'**
  String get activateWorkspaceSubtitle;

  /// No description provided for @sectionCalendarBasics.
  ///
  /// In en, this message translates to:
  /// **'CALENDAR & BASICS'**
  String get sectionCalendarBasics;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name (e.g. Fire department)'**
  String get displayNameLabel;

  /// No description provided for @readOnlySubscription.
  ///
  /// In en, this message translates to:
  /// **'Read-only subscription (.ics)'**
  String get readOnlySubscription;

  /// No description provided for @serverUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL (WebDAV / CalDAV)'**
  String get serverUrlLabel;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @sectionTodos.
  ///
  /// In en, this message translates to:
  /// **'TASKS (TO-DOS)'**
  String get sectionTodos;

  /// No description provided for @enableTodoModule.
  ///
  /// In en, this message translates to:
  /// **'Enable to-do module'**
  String get enableTodoModule;

  /// No description provided for @enableTodoModuleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks are stored in this CalDAV account.'**
  String get enableTodoModuleSubtitle;

  /// No description provided for @sectionShoppingList.
  ///
  /// In en, this message translates to:
  /// **'SHOPPING LIST'**
  String get sectionShoppingList;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @shoppingCaldav.
  ///
  /// In en, this message translates to:
  /// **'CalDAV (VTODO)'**
  String get shoppingCaldav;

  /// No description provided for @shoppingCaldavSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stores purchases as tasks'**
  String get shoppingCaldavSubtitle;

  /// No description provided for @grocyServer.
  ///
  /// In en, this message translates to:
  /// **'Grocy server'**
  String get grocyServer;

  /// No description provided for @grocyServerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Real smart-home inventory'**
  String get grocyServerSubtitle;

  /// No description provided for @grocyUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Grocy URL'**
  String get grocyUrlLabel;

  /// No description provided for @apiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get apiKeyLabel;

  /// No description provided for @testAndLoadDefaults.
  ///
  /// In en, this message translates to:
  /// **'Test & load defaults'**
  String get testAndLoadDefaults;

  /// No description provided for @defaultsForNewItems.
  ///
  /// In en, this message translates to:
  /// **'Default values for new items'**
  String get defaultsForNewItems;

  /// No description provided for @defaultLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Default location'**
  String get defaultLocationLabel;

  /// No description provided for @defaultUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Default unit'**
  String get defaultUnitLabel;

  /// No description provided for @sectionSettingsSync.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS SYNC (COLORS & TEAM)'**
  String get sectionSettingsSync;

  /// No description provided for @syncLocalNone.
  ///
  /// In en, this message translates to:
  /// **'Local (no sync)'**
  String get syncLocalNone;

  /// No description provided for @syncCaldavJournal.
  ///
  /// In en, this message translates to:
  /// **'CalDAV (VJOURNAL)'**
  String get syncCaldavJournal;

  /// No description provided for @syncCaldavJournalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stored invisibly in the calendar'**
  String get syncCaldavJournalSubtitle;

  /// No description provided for @syncExternalWebdav.
  ///
  /// In en, this message translates to:
  /// **'External WebDAV server'**
  String get syncExternalWebdav;

  /// No description provided for @syncExternalWebdavSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stored as a .json file'**
  String get syncExternalWebdavSubtitle;

  /// No description provided for @webdavUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'WebDAV URL'**
  String get webdavUrlLabel;

  /// No description provided for @deleteWorkspaceButton.
  ///
  /// In en, this message translates to:
  /// **'Delete this workspace'**
  String get deleteWorkspaceButton;

  /// No description provided for @deleteWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete workspace?'**
  String get deleteWorkspaceTitle;

  /// No description provided for @deleteWorkspaceMessage.
  ///
  /// In en, this message translates to:
  /// **'All settings for this workspace will be removed. Events on the server remain untouched.'**
  String get deleteWorkspaceMessage;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @nameUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Name and URL are required.'**
  String get nameUrlRequired;

  /// No description provided for @grocyConnectSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connected successfully & defaults loaded!'**
  String get grocyConnectSuccess;

  /// No description provided for @grocyConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed.'**
  String get grocyConnectFailed;

  /// No description provided for @newListTitle.
  ///
  /// In en, this message translates to:
  /// **'Create new list'**
  String get newListTitle;

  /// No description provided for @newListHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Croatia vacation'**
  String get newListHint;

  /// No description provided for @shareWithFamily.
  ///
  /// In en, this message translates to:
  /// **'Visible to others'**
  String get shareWithFamily;

  /// No description provided for @everyoneSeesListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everyone can see this list'**
  String get everyoneSeesListSubtitle;

  /// No description provided for @onlyYouSeeListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only you can see this list'**
  String get onlyYouSeeListSubtitle;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @renameListTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename list'**
  String get renameListTitle;

  /// No description provided for @deleteListTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get deleteListTitle;

  /// No description provided for @deleteListMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to delete the list \'{listName}\' from the server?'**
  String deleteListMessage(String listName);

  /// No description provided for @blockedByServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked by server'**
  String get blockedByServerTitle;

  /// No description provided for @blockedByServerMessage.
  ///
  /// In en, this message translates to:
  /// **'Your calendar server (e.g. Synology) blocks deleting entire lists through third-party apps for security reasons.\n\nPlease log into your calendar via the browser to delete this list there.'**
  String get blockedByServerMessage;

  /// No description provided for @understood.
  ///
  /// In en, this message translates to:
  /// **'Understood'**
  String get understood;

  /// No description provided for @manageVisibility.
  ///
  /// In en, this message translates to:
  /// **'Manage visibility'**
  String get manageVisibility;

  /// No description provided for @manageVisibilityDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose which lists appear on your dashboard. Hidden lists are not deleted.'**
  String get manageVisibilityDescription;

  /// No description provided for @noListsFoundOnServer.
  ///
  /// In en, this message translates to:
  /// **'No lists found on the server.'**
  String get noListsFoundOnServer;

  /// No description provided for @privateLabel.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get privateLabel;

  /// No description provided for @sharedLabel.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get sharedLabel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @tasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksTitle;

  /// No description provided for @newListMenuItem.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get newListMenuItem;

  /// No description provided for @showPrivateItems.
  ///
  /// In en, this message translates to:
  /// **'Show private items'**
  String get showPrivateItems;

  /// No description provided for @hidePrivateItems.
  ///
  /// In en, this message translates to:
  /// **'Hide private items'**
  String get hidePrivateItems;

  /// No description provided for @noListsFound.
  ///
  /// In en, this message translates to:
  /// **'No lists found.'**
  String get noListsFound;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @newTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get newTaskTitle;

  /// No description provided for @editTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get editTaskTitle;

  /// No description provided for @taskTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'What needs to be done? *'**
  String get taskTitleLabel;

  /// No description provided for @noteOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptionalLabel;

  /// No description provided for @dueDateOptional.
  ///
  /// In en, this message translates to:
  /// **'Due date (optional)'**
  String get dueDateOptional;

  /// No description provided for @dueDatePrefix.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String dueDatePrefix(String date);

  /// No description provided for @allDoneMessage.
  ///
  /// In en, this message translates to:
  /// **'All done!'**
  String get allDoneMessage;

  /// No description provided for @editAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// No description provided for @taskFabLabel.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskFabLabel;

  /// No description provided for @newStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'New store'**
  String get newStoreTitle;

  /// No description provided for @newStoreHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Edeka or hardware store'**
  String get newStoreHint;

  /// No description provided for @deleteStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete store'**
  String get deleteStoreTitle;

  /// No description provided for @deleteStoreMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to remove the profile \'{profile}\'?\n\nThe custom sort order for it will also be permanently deleted.'**
  String deleteStoreMessage(String profile);

  /// No description provided for @profileDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'\'{profile}\' was deleted.'**
  String profileDeletedMessage(String profile);

  /// No description provided for @renameCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename category'**
  String get renameCategoryTitle;

  /// No description provided for @newNameLabel.
  ///
  /// In en, this message translates to:
  /// **'New name'**
  String get newNameLabel;

  /// No description provided for @editItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get editItemTitle;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category (e.g. FRIDGE)'**
  String get categoryLabel;

  /// No description provided for @categoryHelperText.
  ///
  /// In en, this message translates to:
  /// **'Determines the sort order for stores'**
  String get categoryHelperText;

  /// No description provided for @noShoppingListActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'No shopping list active'**
  String get noShoppingListActiveTitle;

  /// No description provided for @noShoppingListActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable CalDAV or Grocy in the\nsettings for this workspace.'**
  String get noShoppingListActiveSubtitle;

  /// No description provided for @searchArticleHint.
  ///
  /// In en, this message translates to:
  /// **'Search item...'**
  String get searchArticleHint;

  /// No description provided for @addArticleHint.
  ///
  /// In en, this message translates to:
  /// **'Add item...'**
  String get addArticleHint;

  /// No description provided for @allBoughtMessage.
  ///
  /// In en, this message translates to:
  /// **'All bought!'**
  String get allBoughtMessage;

  /// No description provided for @colorForGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Color for:\n{group}'**
  String colorForGroupTitle(String group);

  /// No description provided for @groupColorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Team colors'**
  String get groupColorsTitle;

  /// No description provided for @noGroupCalendarsFound.
  ///
  /// In en, this message translates to:
  /// **'No group calendars found.\nPlease check \'Calendar mapping\' first.'**
  String get noGroupCalendarsFound;

  /// No description provided for @tapToChangeColor.
  ///
  /// In en, this message translates to:
  /// **'Tap to change color'**
  String get tapToChangeColor;

  /// No description provided for @addPersonTitle.
  ///
  /// In en, this message translates to:
  /// **'Add person'**
  String get addPersonTitle;

  /// No description provided for @editPersonTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit person'**
  String get editPersonTitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @chooseColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose color:'**
  String get chooseColorLabel;

  /// No description provided for @teamAndColorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Team & colors'**
  String get teamAndColorsTitle;

  /// No description provided for @noWorkspaceAvailable.
  ///
  /// In en, this message translates to:
  /// **'No workspace available.'**
  String get noWorkspaceAvailable;

  /// No description provided for @noPeopleInWorkspace.
  ///
  /// In en, this message translates to:
  /// **'No people in this workspace.'**
  String get noPeopleInWorkspace;

  /// No description provided for @addFirstPerson.
  ///
  /// In en, this message translates to:
  /// **'Add first person'**
  String get addFirstPerson;

  /// No description provided for @mapCalendarsTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign calendars'**
  String get mapCalendarsTitle;

  /// No description provided for @noActiveAccountsFound.
  ///
  /// In en, this message translates to:
  /// **'No active accounts found.'**
  String get noActiveAccountsFound;

  /// No description provided for @loadingFoldersAndPeople.
  ///
  /// In en, this message translates to:
  /// **'Loading folders & people...'**
  String get loadingFoldersAndPeople;

  /// No description provided for @noCalendarsFound.
  ///
  /// In en, this message translates to:
  /// **'No calendars found.'**
  String get noCalendarsFound;

  /// No description provided for @folderLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder: \"{name}\"'**
  String folderLabel(String name);

  /// No description provided for @assignedPeopleLabel.
  ///
  /// In en, this message translates to:
  /// **'Assigned people:'**
  String get assignedPeopleLabel;

  /// No description provided for @noPeopleAssignedYet.
  ///
  /// In en, this message translates to:
  /// **'No people set up in this workspace yet.'**
  String get noPeopleAssignedYet;

  /// No description provided for @uploadSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Uploaded successfully!'**
  String get uploadSuccessMessage;

  /// No description provided for @downloadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error while downloading.'**
  String get downloadErrorMessage;

  /// No description provided for @nothingToSyncMessage.
  ///
  /// In en, this message translates to:
  /// **'Everything is up to date. No changes on the server.'**
  String get nothingToSyncMessage;

  /// No description provided for @applyChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply changes?'**
  String get applyChangesTitle;

  /// No description provided for @diffAdded.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get diffAdded;

  /// No description provided for @diffChanged.
  ///
  /// In en, this message translates to:
  /// **'CHANGED'**
  String get diffChanged;

  /// No description provided for @diffRemoved.
  ///
  /// In en, this message translates to:
  /// **'WILL BE REMOVED'**
  String get diffRemoved;

  /// No description provided for @deviceFilterNote.
  ///
  /// In en, this message translates to:
  /// **'Note: The selected device filters are applied.'**
  String get deviceFilterNote;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @settingsAppliedMessage.
  ///
  /// In en, this message translates to:
  /// **'Settings applied!'**
  String get settingsAppliedMessage;

  /// No description provided for @noWorkspacesConfigured.
  ///
  /// In en, this message translates to:
  /// **'No workspaces configured.'**
  String get noWorkspacesConfigured;

  /// No description provided for @activeWorkspaceLabel.
  ///
  /// In en, this message translates to:
  /// **'Active workspace'**
  String get activeWorkspaceLabel;

  /// No description provided for @configuredBackendLabel.
  ///
  /// In en, this message translates to:
  /// **'Configured backend'**
  String get configuredBackendLabel;

  /// No description provided for @noSyncBackendConfigured.
  ///
  /// In en, this message translates to:
  /// **'No sync backend is configured for this workspace. You can enable this under \'Workspaces & Accounts\'.'**
  String get noSyncBackendConfigured;

  /// No description provided for @synologyWebdavLabel.
  ///
  /// In en, this message translates to:
  /// **'Synology WebDAV'**
  String get synologyWebdavLabel;

  /// No description provided for @caldavPiggybackLabel.
  ///
  /// In en, this message translates to:
  /// **'CalDAV piggyback'**
  String get caldavPiggybackLabel;

  /// No description provided for @fileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'File name: {name}'**
  String fileNameLabel(String name);

  /// No description provided for @deviceFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Device filters'**
  String get deviceFiltersLabel;

  /// No description provided for @teamAndCalendarColorsLabel.
  ///
  /// In en, this message translates to:
  /// **'Team & calendar colors'**
  String get teamAndCalendarColorsLabel;

  /// No description provided for @storesNamesLabel.
  ///
  /// In en, this message translates to:
  /// **'Stores (names)'**
  String get storesNamesLabel;

  /// No description provided for @routesLabel.
  ///
  /// In en, this message translates to:
  /// **'Routes (navigation)'**
  String get routesLabel;

  /// No description provided for @checkAndLoad.
  ///
  /// In en, this message translates to:
  /// **'Check & load'**
  String get checkAndLoad;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @chooseColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose color'**
  String get chooseColorTitle;

  /// No description provided for @recurrenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get recurrenceTitle;

  /// No description provided for @recurrenceNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get recurrenceNone;

  /// No description provided for @recurrenceDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get recurrenceDaily;

  /// No description provided for @recurrenceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get recurrenceWeekly;

  /// No description provided for @recurrenceBiWeekly.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get recurrenceBiWeekly;

  /// No description provided for @recurrenceMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get recurrenceMonthly;

  /// No description provided for @recurrenceCustomDays.
  ///
  /// In en, this message translates to:
  /// **'Specific weekdays'**
  String get recurrenceCustomDays;

  /// No description provided for @chooseWeekdaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose weekdays'**
  String get chooseWeekdaysTitle;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @editEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get editEventTitle;

  /// No description provided for @eventTitle.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get eventTitle;

  /// No description provided for @saveToAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Save to account:'**
  String get saveToAccountLabel;

  /// No description provided for @selectGuestsLabel.
  ///
  /// In en, this message translates to:
  /// **'Select guests'**
  String get selectGuestsLabel;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get deselectAll;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @combinationValidMessage.
  ///
  /// In en, this message translates to:
  /// **'Combination valid. Ready to save.'**
  String get combinationValidMessage;

  /// No description provided for @noFolderAssignedMessage.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Please assign a server folder to this account first, under \'Settings -> Assign calendars\'.'**
  String get noFolderAssignedMessage;

  /// No description provided for @noSharedFolderMessage.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Invalid: there is no shared folder for this guest selection in this account.'**
  String get noSharedFolderMessage;

  /// No description provided for @changeColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Change color'**
  String get changeColorLabel;

  /// No description provided for @repeatSummary.
  ///
  /// In en, this message translates to:
  /// **'Repeat: {value}'**
  String repeatSummary(String value);

  /// No description provided for @neverEnds.
  ///
  /// In en, this message translates to:
  /// **'Never ends'**
  String get neverEnds;

  /// No description provided for @endsOn.
  ///
  /// In en, this message translates to:
  /// **'Ends on: {date}'**
  String endsOn(String date);

  /// No description provided for @minutesBeforeLabel.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes before'**
  String minutesBeforeLabel(int minutes);

  /// No description provided for @noReminderLabel.
  ///
  /// In en, this message translates to:
  /// **'No reminder'**
  String get noReminderLabel;

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderTitle;

  /// No description provided for @oneHourBeforeLabel.
  ///
  /// In en, this message translates to:
  /// **'1 hour before'**
  String get oneHourBeforeLabel;

  /// No description provided for @oneDayBeforeLabel.
  ///
  /// In en, this message translates to:
  /// **'1 day before'**
  String get oneDayBeforeLabel;

  /// No description provided for @addLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get addLocationHint;

  /// No description provided for @helpLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading the guide.'**
  String get helpLoadError;

  /// No description provided for @newCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategoryTitle;

  /// No description provided for @newCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Drugstore'**
  String get newCategoryHint;

  /// No description provided for @newItemTitle.
  ///
  /// In en, this message translates to:
  /// **'New item'**
  String get newItemTitle;

  /// No description provided for @whatDoYouNeedLabel.
  ///
  /// In en, this message translates to:
  /// **'What do you need?'**
  String get whatDoYouNeedLabel;

  /// No description provided for @pleaseEnterNameValidator.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get pleaseEnterNameValidator;

  /// No description provided for @categoryPlainLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryPlainLabel;

  /// No description provided for @pleaseSelectValidator.
  ///
  /// In en, this message translates to:
  /// **'Please select'**
  String get pleaseSelectValidator;

  /// No description provided for @newCategoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create new category'**
  String get newCategoryTooltip;

  /// No description provided for @addButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButtonLabel;

  /// No description provided for @editMasterDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit master data'**
  String get editMasterDataTitle;

  /// No description provided for @editMasterDataWarning.
  ///
  /// In en, this message translates to:
  /// **'Caution: changes the name across the entire inventory!'**
  String get editMasterDataWarning;

  /// No description provided for @routeTitle.
  ///
  /// In en, this message translates to:
  /// **'Route: {profile}'**
  String routeTitle(String profile);

  /// No description provided for @reorderCategoriesInstructions.
  ///
  /// In en, this message translates to:
  /// **'Press and hold a category, then drag it to the right position for your store.'**
  String get reorderCategoriesInstructions;

  /// No description provided for @searchEventsHint.
  ///
  /// In en, this message translates to:
  /// **'Search events...'**
  String get searchEventsHint;

  /// No description provided for @enterTitleOrLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Enter title or location...'**
  String get enterTitleOrLocationHint;

  /// No description provided for @noEventsFoundForQuery.
  ///
  /// In en, this message translates to:
  /// **'No events found for \'{query}\'.'**
  String noEventsFoundForQuery(String query);

  /// No description provided for @filterViewTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter view'**
  String get filterViewTitle;

  /// No description provided for @saveAsPreset.
  ///
  /// In en, this message translates to:
  /// **'Save as preset'**
  String get saveAsPreset;

  /// No description provided for @quickSelect.
  ///
  /// In en, this message translates to:
  /// **'Quick select'**
  String get quickSelect;

  /// No description provided for @manualSelection.
  ///
  /// In en, this message translates to:
  /// **'Manual selection'**
  String get manualSelection;

  /// No description provided for @newPresetTitle.
  ///
  /// In en, this message translates to:
  /// **'Save new preset'**
  String get newPresetTitle;

  /// No description provided for @presetNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name (e.g. Fire dept only)'**
  String get presetNameHint;

  /// No description provided for @presetSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Preset saved!'**
  String get presetSavedMessage;

  /// No description provided for @showAllPresetName.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAllPresetName;

  /// No description provided for @untitledEventFallback.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitledEventFallback;

  /// No description provided for @unnamedTaskFallback.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get unnamedTaskFallback;

  /// No description provided for @syncNewStore.
  ///
  /// In en, this message translates to:
  /// **'New store: {name}'**
  String syncNewStore(String name);

  /// No description provided for @syncStoreRemoved.
  ///
  /// In en, this message translates to:
  /// **'Store removed: {name}'**
  String syncStoreRemoved(String name);

  /// No description provided for @syncRoutesChanged.
  ///
  /// In en, this message translates to:
  /// **'Store routes (sort order) were changed'**
  String get syncRoutesChanged;

  /// No description provided for @syncTeamOrColorsChanged.
  ///
  /// In en, this message translates to:
  /// **'People or calendar colors were changed'**
  String get syncTeamOrColorsChanged;

  /// No description provided for @syncServerError.
  ///
  /// In en, this message translates to:
  /// **'Server responded with code: {code}'**
  String syncServerError(int code);

  /// No description provided for @syncNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error: {error}'**
  String syncNetworkError(String error);

  /// No description provided for @syncNoActiveAccount.
  ///
  /// In en, this message translates to:
  /// **'No active CalDAV account found.'**
  String get syncNoActiveAccount;

  /// No description provided for @syncNoTaskListFound.
  ///
  /// In en, this message translates to:
  /// **'No task list found in the CalDAV account.'**
  String get syncNoTaskListFound;

  /// No description provided for @syncCaldavError.
  ///
  /// In en, this message translates to:
  /// **'CalDAV error: {error}'**
  String syncCaldavError(String error);

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Team Calendar'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminders for upcoming events'**
  String get notificationChannelDescription;

  /// No description provided for @notificationTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'📅 Event reminder'**
  String get notificationTitleLabel;

  /// No description provided for @notificationEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Event: {title}'**
  String notificationEventTitle(String title);

  /// No description provided for @notificationBodyMinutes.
  ///
  /// In en, this message translates to:
  /// **'Starts in {minutes} minutes'**
  String notificationBodyMinutes(int minutes);

  /// No description provided for @notificationBigTextBody.
  ///
  /// In en, this message translates to:
  /// **'The event <b>\"{title}\"</b> starts in {minutes} minutes.<br><br><b>Location:</b> {location}'**
  String notificationBigTextBody(String title, int minutes, String location);

  /// No description provided for @notificationLocationNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get notificationLocationNotSpecified;

  /// No description provided for @notAppliedFilterOff.
  ///
  /// In en, this message translates to:
  /// **'Won\'t be applied - filter is off'**
  String get notAppliedFilterOff;

  /// No description provided for @nothingWillBeAppliedMessage.
  ///
  /// In en, this message translates to:
  /// **'None of this will be applied with your current filters.'**
  String get nothingWillBeAppliedMessage;
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
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
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
