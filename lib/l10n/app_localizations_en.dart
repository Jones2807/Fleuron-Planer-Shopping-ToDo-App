// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fleuron';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageGerman => 'German';

  @override
  String get languageEnglish => 'English';

  @override
  String get userSwitchDialogTitle => 'Who\'s using this phone?';

  @override
  String get holidaySettingsTitle => 'Country & Holidays';

  @override
  String get holidaySettingsDescription =>
      'Choose which holidays should be marked in the calendar.';

  @override
  String get countryLabel => 'Country';

  @override
  String get regionLabel => 'State';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get countryGermany => 'Germany';

  @override
  String get countryAustria => 'Austria';

  @override
  String get countrySwitzerland => 'Switzerland';

  @override
  String get regionNone => 'No specific region';

  @override
  String get deleteRecurringEventTitle => 'Delete recurring event';

  @override
  String get deleteRecurringEventMessage =>
      'Do you want to delete only this occurrence or the entire series?';

  @override
  String get deleteThisOccurrence => 'Only this occurrence';

  @override
  String get deleteEntireSeries => 'Entire series';

  @override
  String get searchTooltip => 'Search';

  @override
  String get viewSelectorTooltip => 'Select view';

  @override
  String get todayTooltip => 'Today';

  @override
  String get viewMonth => 'Month view';

  @override
  String get viewTwoWeeks => '14 days';

  @override
  String get viewWeek => 'Week view';

  @override
  String get newEvent => 'New event';

  @override
  String get todos => 'To-dos';

  @override
  String get shoppingList => 'Shopping list';

  @override
  String get noEvents => 'No events';

  @override
  String get allDay => 'All day';

  @override
  String get allDayShort => 'All\nday';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get activeProfile => 'Active profile';

  @override
  String get sectionView => 'VIEW';

  @override
  String get grayOutPastEventsLabel => 'Gray out past events';

  @override
  String get weekNumbersLabel => 'Week numbers';

  @override
  String get showHolidaysLabel => 'Show holidays';

  @override
  String get sectionSettings => 'SETTINGS';

  @override
  String get teamAndGroups => 'Team & groups';

  @override
  String get addPeople => 'Add people';

  @override
  String get teamColors => 'Team colors (groups)';

  @override
  String get assignFolders => 'Assign folders';

  @override
  String get workspacesAndAccounts => 'Workspaces & accounts';

  @override
  String get teamSyncManual => 'Team sync (manual)';

  @override
  String get helpAndGuide => 'Guide & help';

  @override
  String get readOnlyCalendarSubtitle => 'Read-only calendar';

  @override
  String get caldavWorkspaceSubtitle => 'CalDAV workspace';

  @override
  String get newWorkspace => 'New workspace';

  @override
  String get noWorkspacesTitle => 'No workspaces yet';

  @override
  String get noWorkspacesSubtitle =>
      'Create a separate workspace for\neach family or organization.';

  @override
  String get newWorkspaceTitle => 'Create new workspace';

  @override
  String get editWorkspaceTitle => 'Edit workspace';

  @override
  String get activateWorkspace => 'Activate workspace';

  @override
  String get activateWorkspaceSubtitle => 'Makes this area visible in the app';

  @override
  String get sectionCalendarBasics => 'CALENDAR & BASICS';

  @override
  String get displayNameLabel => 'Display name (e.g. Fire department)';

  @override
  String get readOnlySubscription => 'Read-only subscription (.ics)';

  @override
  String get serverUrlLabel => 'Server URL (WebDAV / CalDAV)';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordLabel => 'Password';

  @override
  String get sectionTodos => 'TASKS (TO-DOS)';

  @override
  String get enableTodoModule => 'Enable to-do module';

  @override
  String get enableTodoModuleSubtitle =>
      'Tasks are stored in this CalDAV account.';

  @override
  String get sectionShoppingList => 'SHOPPING LIST';

  @override
  String get disabled => 'Disabled';

  @override
  String get shoppingCaldav => 'CalDAV (VTODO)';

  @override
  String get shoppingCaldavSubtitle => 'Stores purchases as tasks';

  @override
  String get grocyServer => 'Grocy server';

  @override
  String get grocyServerSubtitle => 'Real smart-home inventory';

  @override
  String get grocyUrlLabel => 'Grocy URL';

  @override
  String get apiKeyLabel => 'API key';

  @override
  String get testAndLoadDefaults => 'Test & load defaults';

  @override
  String get defaultsForNewItems => 'Default values for new items';

  @override
  String get defaultLocationLabel => 'Default location';

  @override
  String get defaultUnitLabel => 'Default unit';

  @override
  String get sectionSettingsSync => 'SETTINGS SYNC (COLORS & TEAM)';

  @override
  String get syncLocalNone => 'Local (no sync)';

  @override
  String get syncCaldavJournal => 'CalDAV (VJOURNAL)';

  @override
  String get syncCaldavJournalSubtitle => 'Stored invisibly in the calendar';

  @override
  String get syncExternalWebdav => 'External WebDAV server';

  @override
  String get syncExternalWebdavSubtitle => 'Stored as a .json file';

  @override
  String get webdavUrlLabel => 'WebDAV URL';

  @override
  String get deleteWorkspaceButton => 'Delete this workspace';

  @override
  String get deleteWorkspaceTitle => 'Delete workspace?';

  @override
  String get deleteWorkspaceMessage =>
      'All settings for this workspace will be removed. Events on the server remain untouched.';

  @override
  String get delete => 'Delete';

  @override
  String get nameUrlRequired => 'Name and URL are required.';

  @override
  String get grocyConnectSuccess => 'Connected successfully & defaults loaded!';

  @override
  String get grocyConnectFailed => 'Connection failed.';

  @override
  String get newListTitle => 'Create new list';

  @override
  String get newListHint => 'e.g. Croatia vacation';

  @override
  String get shareWithFamily => 'Visible to others';

  @override
  String get everyoneSeesListSubtitle => 'Everyone can see this list';

  @override
  String get onlyYouSeeListSubtitle => 'Only you can see this list';

  @override
  String get create => 'Create';

  @override
  String get renameListTitle => 'Rename list';

  @override
  String get deleteListTitle => 'Delete list';

  @override
  String deleteListMessage(String listName) {
    return 'Do you really want to delete the list \'$listName\' from the server?';
  }

  @override
  String get blockedByServerTitle => 'Blocked by server';

  @override
  String get blockedByServerMessage =>
      'Your calendar server (e.g. Synology) blocks deleting entire lists through third-party apps for security reasons.\n\nPlease log into your calendar via the browser to delete this list there.';

  @override
  String get understood => 'Understood';

  @override
  String get manageVisibility => 'Manage visibility';

  @override
  String get manageVisibilityDescription =>
      'Choose which lists appear on your dashboard. Hidden lists are not deleted.';

  @override
  String get noListsFoundOnServer => 'No lists found on the server.';

  @override
  String get privateLabel => 'Private';

  @override
  String get sharedLabel => 'Shared';

  @override
  String get done => 'Done';

  @override
  String get tasksTitle => 'Tasks';

  @override
  String get newListMenuItem => 'New list';

  @override
  String get showPrivateItems => 'Show private items';

  @override
  String get hidePrivateItems => 'Hide private items';

  @override
  String get noListsFound => 'No lists found.';

  @override
  String get rename => 'Rename';

  @override
  String get hide => 'Hide';

  @override
  String get newTaskTitle => 'New task';

  @override
  String get editTaskTitle => 'Edit task';

  @override
  String get taskTitleLabel => 'What needs to be done? *';

  @override
  String get noteOptionalLabel => 'Note (optional)';

  @override
  String get dueDateOptional => 'Due date (optional)';

  @override
  String dueDatePrefix(String date) {
    return 'Due: $date';
  }

  @override
  String get allDoneMessage => 'All done!';

  @override
  String get editAction => 'Edit';

  @override
  String get taskFabLabel => 'Task';

  @override
  String get newStoreTitle => 'New store';

  @override
  String get newStoreHint => 'e.g. Edeka or hardware store';

  @override
  String get deleteStoreTitle => 'Delete store';

  @override
  String deleteStoreMessage(String profile) {
    return 'Do you really want to remove the profile \'$profile\'?\n\nThe custom sort order for it will also be permanently deleted.';
  }

  @override
  String profileDeletedMessage(String profile) {
    return '\'$profile\' was deleted.';
  }

  @override
  String get renameCategoryTitle => 'Rename category';

  @override
  String get newNameLabel => 'New name';

  @override
  String get editItemTitle => 'Edit item';

  @override
  String get titleLabel => 'Title';

  @override
  String get categoryLabel => 'Category (e.g. FRIDGE)';

  @override
  String get categoryHelperText => 'Determines the sort order for stores';

  @override
  String get noShoppingListActiveTitle => 'No shopping list active';

  @override
  String get noShoppingListActiveSubtitle =>
      'Enable CalDAV or Grocy in the\nsettings for this workspace.';

  @override
  String get searchArticleHint => 'Search item...';

  @override
  String get addArticleHint => 'Add item...';

  @override
  String get allBoughtMessage => 'All bought!';

  @override
  String colorForGroupTitle(String group) {
    return 'Color for:\n$group';
  }

  @override
  String get groupColorsTitle => 'Team colors';

  @override
  String get noGroupCalendarsFound =>
      'No group calendars found.\nPlease check \'Calendar mapping\' first.';

  @override
  String get tapToChangeColor => 'Tap to change color';

  @override
  String get addPersonTitle => 'Add person';

  @override
  String get editPersonTitle => 'Edit person';

  @override
  String get nameLabel => 'Name';

  @override
  String get chooseColorLabel => 'Choose color:';

  @override
  String get teamAndColorsTitle => 'Team & colors';

  @override
  String get noWorkspaceAvailable => 'No workspace available.';

  @override
  String get noPeopleInWorkspace => 'No people in this workspace.';

  @override
  String get addFirstPerson => 'Add first person';

  @override
  String get mapCalendarsTitle => 'Assign calendars';

  @override
  String get noActiveAccountsFound => 'No active accounts found.';

  @override
  String get loadingFoldersAndPeople => 'Loading folders & people...';

  @override
  String get noCalendarsFound => 'No calendars found.';

  @override
  String folderLabel(String name) {
    return 'Folder: \"$name\"';
  }

  @override
  String get assignedPeopleLabel => 'Assigned people:';

  @override
  String get noPeopleAssignedYet => 'No people set up in this workspace yet.';

  @override
  String get uploadSuccessMessage => 'Uploaded successfully!';

  @override
  String get downloadErrorMessage => 'Error while downloading.';

  @override
  String get nothingToSyncMessage =>
      'Everything is up to date. No changes on the server.';

  @override
  String get applyChangesTitle => 'Apply changes?';

  @override
  String get diffAdded => 'NEW';

  @override
  String get diffChanged => 'CHANGED';

  @override
  String get diffRemoved => 'WILL BE REMOVED';

  @override
  String get deviceFilterNote =>
      'Note: The selected device filters are applied.';

  @override
  String get update => 'Update';

  @override
  String get settingsAppliedMessage => 'Settings applied!';

  @override
  String get noWorkspacesConfigured => 'No workspaces configured.';

  @override
  String get activeWorkspaceLabel => 'Active workspace';

  @override
  String get configuredBackendLabel => 'Configured backend';

  @override
  String get noSyncBackendConfigured =>
      'No sync backend is configured for this workspace. You can enable this under \'Workspaces & Accounts\'.';

  @override
  String get synologyWebdavLabel => 'Synology WebDAV';

  @override
  String get caldavPiggybackLabel => 'CalDAV piggyback';

  @override
  String fileNameLabel(String name) {
    return 'File name: $name';
  }

  @override
  String get deviceFiltersLabel => 'Device filters';

  @override
  String get teamAndCalendarColorsLabel => 'Team & calendar colors';

  @override
  String get storesNamesLabel => 'Stores (names)';

  @override
  String get routesLabel => 'Routes (navigation)';

  @override
  String get checkAndLoad => 'Check & load';

  @override
  String get send => 'Send';

  @override
  String get chooseColorTitle => 'Choose color';

  @override
  String get recurrenceTitle => 'Repeat';

  @override
  String get recurrenceNone => 'None';

  @override
  String get recurrenceDaily => 'Daily';

  @override
  String get recurrenceWeekly => 'Weekly';

  @override
  String get recurrenceBiWeekly => 'Every 2 weeks';

  @override
  String get recurrenceMonthly => 'Monthly';

  @override
  String get recurrenceCustomDays => 'Specific weekdays';

  @override
  String get chooseWeekdaysTitle => 'Choose weekdays';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get editEventTitle => 'Edit event';

  @override
  String get eventTitle => 'Event';

  @override
  String get saveToAccountLabel => 'Save to account:';

  @override
  String get selectGuestsLabel => 'Select guests';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get selectAll => 'Select all';

  @override
  String get combinationValidMessage => 'Combination valid. Ready to save.';

  @override
  String get noFolderAssignedMessage =>
      '⚠️ Please assign a server folder to this account first, under \'Settings -> Assign calendars\'.';

  @override
  String get noSharedFolderMessage =>
      '⚠️ Invalid: there is no shared folder for this guest selection in this account.';

  @override
  String get changeColorLabel => 'Change color';

  @override
  String repeatSummary(String value) {
    return 'Repeat: $value';
  }

  @override
  String get neverEnds => 'Never ends';

  @override
  String endsOn(String date) {
    return 'Ends on: $date';
  }

  @override
  String minutesBeforeLabel(int minutes) {
    return '$minutes minutes before';
  }

  @override
  String get noReminderLabel => 'No reminder';

  @override
  String get reminderTitle => 'Reminder';

  @override
  String get oneHourBeforeLabel => '1 hour before';

  @override
  String get oneDayBeforeLabel => '1 day before';

  @override
  String get addLocationHint => 'Add location';

  @override
  String get helpLoadError => 'Error loading the guide.';

  @override
  String get newCategoryTitle => 'New category';

  @override
  String get newCategoryHint => 'e.g. Drugstore';

  @override
  String get newItemTitle => 'New item';

  @override
  String get whatDoYouNeedLabel => 'What do you need?';

  @override
  String get pleaseEnterNameValidator => 'Please enter a name';

  @override
  String get categoryPlainLabel => 'Category';

  @override
  String get pleaseSelectValidator => 'Please select';

  @override
  String get newCategoryTooltip => 'Create new category';

  @override
  String get addButtonLabel => 'Add';

  @override
  String get editMasterDataTitle => 'Edit master data';

  @override
  String get editMasterDataWarning =>
      'Caution: changes the name across the entire inventory!';

  @override
  String routeTitle(String profile) {
    return 'Route: $profile';
  }

  @override
  String get reorderCategoriesInstructions =>
      'Press and hold a category, then drag it to the right position for your store.';

  @override
  String get searchEventsHint => 'Search events...';

  @override
  String get enterTitleOrLocationHint => 'Enter title or location...';

  @override
  String noEventsFoundForQuery(String query) {
    return 'No events found for \'$query\'.';
  }

  @override
  String get filterViewTitle => 'Filter view';

  @override
  String get saveAsPreset => 'Save as preset';

  @override
  String get quickSelect => 'Quick select';

  @override
  String get manualSelection => 'Manual selection';

  @override
  String get newPresetTitle => 'Save new preset';

  @override
  String get presetNameHint => 'Name (e.g. Fire dept only)';

  @override
  String get presetSavedMessage => 'Preset saved!';

  @override
  String get showAllPresetName => 'Show all';

  @override
  String get untitledEventFallback => 'Untitled';

  @override
  String get unnamedTaskFallback => 'Unnamed';

  @override
  String syncNewStore(String name) {
    return 'New store: $name';
  }

  @override
  String syncStoreRemoved(String name) {
    return 'Store removed: $name';
  }

  @override
  String get syncRoutesChanged => 'Store routes (sort order) were changed';

  @override
  String get syncTeamOrColorsChanged =>
      'People or calendar colors were changed';

  @override
  String syncServerError(int code) {
    return 'Server responded with code: $code';
  }

  @override
  String syncNetworkError(String error) {
    return 'Network error: $error';
  }

  @override
  String get syncNoActiveAccount => 'No active CalDAV account found.';

  @override
  String get syncNoTaskListFound => 'No task list found in the CalDAV account.';

  @override
  String syncCaldavError(String error) {
    return 'CalDAV error: $error';
  }

  @override
  String get notificationChannelName => 'Team Calendar';

  @override
  String get notificationChannelDescription => 'Reminders for upcoming events';

  @override
  String get notificationTitleLabel => '📅 Event reminder';

  @override
  String notificationEventTitle(String title) {
    return 'Event: $title';
  }

  @override
  String notificationBodyMinutes(int minutes) {
    return 'Starts in $minutes minutes';
  }

  @override
  String notificationBigTextBody(String title, int minutes, String location) {
    return 'The event <b>\"$title\"</b> starts in $minutes minutes.<br><br><b>Location:</b> $location';
  }

  @override
  String get notificationLocationNotSpecified => 'Not specified';

  @override
  String get notAppliedFilterOff => 'Won\'t be applied - filter is off';

  @override
  String get nothingWillBeAppliedMessage =>
      'None of this will be applied with your current filters.';
}
