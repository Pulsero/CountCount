#import "SettingsController.h"

#import "Countdown.hpp"

NSString* const CountCountShowIconKey = @"showIcon";
NSString* const CountCountShowTitleKey = @"showTitle";

static const CGFloat kFormWidth = 352;

static NSString* LimitedTitle(NSString* text, NSUInteger maxCharacters) {
    if (text.length == 0 || maxCharacters == 0) {
        return @"";
    }
    __block NSUInteger count = 0;
    __block NSUInteger end = 0;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                              options:NSStringEnumerationByComposedCharacterSequences
                           usingBlock:^(NSString* substring, NSRange range, NSRange, BOOL* stop) {
                               (void)substring;
                               if (count >= maxCharacters) {
                                   *stop = YES;
                                   return;
                               }
                               ++count;
                               end = NSMaxRange(range);
                           }];
    return end < text.length ? [text substringToIndex:end] : text;
}

static NSTextField* Caption(NSString* text) {
    NSTextField* label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    label.textColor = NSColor.secondaryLabelColor;
    return label;
}

static BOOL SameDay(NSCalendar* calendar, NSDate* lhs, NSDate* rhs) {
    if (lhs == nil || rhs == nil) {
        return NO;
    }
    NSCalendarUnit units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
    NSDateComponents* left = [calendar components:units fromDate:lhs];
    NSDateComponents* right = [calendar components:units fromDate:rhs];
    return left.year == right.year && left.month == right.month && left.day == right.day;
}

@interface SettingsController () <NSTextFieldDelegate, NSWindowDelegate>
@end

@implementation SettingsController {
    __weak id<SettingsControllerDelegate> _settingsDelegate;
    NSTextField* _titleField;
    NSDatePicker* _datePicker;
    NSButton* _showIconCheckbox;
    NSButton* _showTitleCheckbox;
    NSButton* _clearButton;
    NSTextField* _errorLabel;
    NSString* _title;
    NSString* _message;
    NSInteger _year;
    NSInteger _month;
    NSInteger _day;
    BOOL _configured;
    BOOL _updating;
}

- (instancetype)initWithDelegate:(id<SettingsControllerDelegate>)delegate {
    NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 420, 560)
                                                    styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskMiniaturizable
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
    self = [super initWithWindow:window];
    if (self == nil) {
        return nil;
    }
    _settingsDelegate = delegate;
    _title = @"";
    window.title = @"Settings";
    window.releasedWhenClosed = NO;
    window.hidesOnDeactivate = NO;
    window.level = NSFloatingWindowLevel;
    window.collectionBehavior = NSWindowCollectionBehaviorMoveToActiveSpace |
                                NSWindowCollectionBehaviorFullScreenAuxiliary;
    window.delegate = self;
    [self buildContentInWindow:window];
    [self pushToControls];
    [window center];
    return self;
}

- (void)buildContentInWindow:(NSWindow*)window {
    NSView* root = window.contentView;
    NSStackView* stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 8;
    stack.detachesHiddenViews = YES;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField* nameCaption = Caption(@"Event name");
    [stack addArrangedSubview:nameCaption];
    [stack setCustomSpacing:4 afterView:nameCaption];
    _titleField = [NSTextField textFieldWithString:@""];
    _titleField.placeholderString = @"Birthday, launch, trip";
    _titleField.font = [NSFont systemFontOfSize:13];
    _titleField.delegate = self;
    _titleField.translatesAutoresizingMaskIntoConstraints = NO;
    [_titleField.widthAnchor constraintEqualToConstant:kFormWidth].active = YES;
    [stack addArrangedSubview:_titleField];
    [stack setCustomSpacing:16 afterView:_titleField];

    NSTextField* dateCaption = Caption(@"Date");
    [stack addArrangedSubview:dateCaption];
    [stack setCustomSpacing:6 afterView:dateCaption];

    _datePicker = [[NSDatePicker alloc] initWithFrame:NSZeroRect];
    _datePicker.datePickerStyle = NSDatePickerStyleClockAndCalendar;
    _datePicker.datePickerMode = NSDatePickerModeSingle;
    _datePicker.datePickerElements = NSDatePickerElementFlagYearMonthDay;
    _datePicker.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    NSCalendar* calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    calendar.locale = _datePicker.locale;
    _datePicker.calendar = calendar;
    _datePicker.dateValue = [NSDate date];
    _datePicker.target = self;
    _datePicker.action = @selector(dateChanged:);
    _datePicker.translatesAutoresizingMaskIntoConstraints = NO;
    [_datePicker setContentHuggingPriority:NSLayoutPriorityRequired
                            forOrientation:NSLayoutConstraintOrientationVertical];
    [_datePicker setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                          forOrientation:NSLayoutConstraintOrientationVertical];

    NSView* leadingSpacer = [[NSView alloc] initWithFrame:NSZeroRect];
    NSView* trailingSpacer = [[NSView alloc] initWithFrame:NSZeroRect];
    [leadingSpacer setContentHuggingPriority:NSLayoutPriorityDefaultLow
                              forOrientation:NSLayoutConstraintOrientationHorizontal];
    [trailingSpacer setContentHuggingPriority:NSLayoutPriorityDefaultLow
                               forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView* pickerRow = [NSStackView stackViewWithViews:@[leadingSpacer, _datePicker, trailingSpacer]];
    pickerRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    pickerRow.alignment = NSLayoutAttributeCenterY;
    pickerRow.distribution = NSStackViewDistributionFill;
    [pickerRow.widthAnchor constraintEqualToConstant:kFormWidth].active = YES;
    [leadingSpacer.widthAnchor constraintEqualToAnchor:trailingSpacer.widthAnchor].active = YES;
    [stack addArrangedSubview:pickerRow];
    [stack setCustomSpacing:16 afterView:pickerRow];

    NSTextField* menuCaption = Caption(@"Menu bar");
    [stack addArrangedSubview:menuCaption];
    [stack setCustomSpacing:4 afterView:menuCaption];
    _showIconCheckbox = [NSButton checkboxWithTitle:@"Show icon" target:self action:@selector(displayChanged:)];
    _showTitleCheckbox = [NSButton checkboxWithTitle:@"Show event name"
                                              target:self
                                              action:@selector(displayChanged:)];
    [stack addArrangedSubview:_showIconCheckbox];
    [stack addArrangedSubview:_showTitleCheckbox];
    [stack setCustomSpacing:14 afterView:_showTitleCheckbox];

    _errorLabel = [NSTextField labelWithString:@""];
    _errorLabel.font = [NSFont systemFontOfSize:12];
    _errorLabel.textColor = NSColor.systemRedColor;
    _errorLabel.maximumNumberOfLines = 2;
    _errorLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _errorLabel.cell.wraps = YES;
    [_errorLabel.widthAnchor constraintEqualToConstant:kFormWidth].active = YES;
    [stack addArrangedSubview:_errorLabel];
    [stack setCustomSpacing:12 afterView:_errorLabel];

    NSTextField* note = [NSTextField labelWithString:@"Changes save automatically."];
    note.font = [NSFont systemFontOfSize:12];
    note.textColor = NSColor.secondaryLabelColor;
    _clearButton = [NSButton buttonWithTitle:@"Clear" target:self action:@selector(clearPressed:)];
    _clearButton.bezelStyle = NSBezelStyleRounded;
    NSView* spacer = [[NSView alloc] initWithFrame:NSZeroRect];
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow
                        forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView* footer = [NSStackView stackViewWithViews:@[note, spacer, _clearButton]];
    footer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    footer.alignment = NSLayoutAttributeCenterY;
    footer.spacing = 8;
    footer.detachesHiddenViews = YES;
    [footer.widthAnchor constraintEqualToConstant:kFormWidth].active = YES;
    [stack addArrangedSubview:footer];

    [root addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:root.topAnchor constant:20],
        [stack.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],
        [stack.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-20],
        [stack.widthAnchor constraintEqualToConstant:kFormWidth],
    ]];
    [root layoutSubtreeIfNeeded];
    const NSSize fitting = [stack fittingSize];
    [window setContentSize:NSMakeSize(MAX(fitting.width + 48, 400), MAX(fitting.height + 40, 240))];
}

- (void)applyTitle:(NSString*)title
              year:(NSInteger)year
             month:(NSInteger)month
               day:(NSInteger)day
        configured:(BOOL)configured {
    _title = title ?: @"";
    _year = year;
    _month = month;
    _day = day;
    _configured = configured;
    _message = nil;
    if (self.isWindowLoaded) {
        [self pushToControls];
    }
}

- (void)showMessage:(NSString*)message {
    _message = [message copy];
    if (self.isWindowLoaded) {
        [self pushMessage];
    }
}

- (NSDate*)dateFromStoredParts {
    if (!_configured || _year <= 0) {
        return nil;
    }
    NSDateComponents* parts = [[NSDateComponents alloc] init];
    parts.year = _year;
    parts.month = _month;
    parts.day = _day;
    parts.hour = 12;
    return [_datePicker.calendar dateFromComponents:parts];
}

- (void)pushToControls {
    _updating = YES;
    if (![_titleField.stringValue isEqualToString:_title]) {
        _titleField.stringValue = _title;
    }
    NSDate* date = [self dateFromStoredParts] ?: [NSDate date];
    id dateTarget = _datePicker.target;
    SEL dateAction = _datePicker.action;
    _datePicker.target = nil;
    _datePicker.action = NULL;
    if (!SameDay(_datePicker.calendar, _datePicker.dateValue, date)) {
        _datePicker.dateValue = date;
    }
    _datePicker.target = dateTarget;
    _datePicker.action = dateAction;
    _clearButton.hidden = !_configured;
    NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
    _showIconCheckbox.state = [defaults boolForKey:CountCountShowIconKey] ? NSControlStateValueOn
                                                                           : NSControlStateValueOff;
    _showTitleCheckbox.state = [defaults boolForKey:CountCountShowTitleKey] ? NSControlStateValueOn
                                                                             : NSControlStateValueOff;
    [self pushMessage];
    _updating = NO;
}

- (void)pushMessage {
    _errorLabel.stringValue = _message ?: @"";
    _errorLabel.hidden = _message.length == 0;
}

- (BOOL)readPickerDate:(countcount::CivilDate*)date {
    NSDateComponents* parts = [_datePicker.calendar components:NSCalendarUnitYear | NSCalendarUnitMonth |
                                                                   NSCalendarUnitDay
                                                       fromDate:_datePicker.dateValue];
    *date = countcount::CivilDate {static_cast<int>(parts.year), static_cast<int>(parts.month),
                                   static_cast<int>(parts.day)};
    return countcount::isValidDate(*date);
}

- (void)commitFromDatePicker:(BOOL)fromDatePicker {
    if (_updating) {
        return;
    }
    countcount::CivilDate date;
    if (![self readPickerDate:&date]) {
        return;
    }
    NSString* title = _titleField.stringValue ?: @"";
    const BOOL sameDate = _configured && date.year == _year && date.month == _month && date.day == _day;
    const BOOL sameTitle = [title isEqualToString:_title ?: @""];
    if (!fromDatePicker && sameDate && sameTitle) {
        return;
    }
    if (!fromDatePicker && !_configured) {
        NSString* trimmed = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmed.length == 0) {
            return;
        }
    }
    [_settingsDelegate settingsController:self
                           didCommitTitle:title
                                     year:date.year
                                    month:date.month
                                      day:date.day];
}

- (void)dateChanged:(id)sender {
    (void)sender;
    _message = nil;
    [self pushMessage];
    [self commitFromDatePicker:YES];
}

- (void)displayChanged:(id)sender {
    (void)sender;
    if (_updating) {
        return;
    }
    NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
    [defaults setBool:_showIconCheckbox.state == NSControlStateValueOn forKey:CountCountShowIconKey];
    [defaults setBool:_showTitleCheckbox.state == NSControlStateValueOn forKey:CountCountShowTitleKey];
    [_settingsDelegate settingsControllerDidChangeDisplay:self];
}

- (void)clearPressed:(id)sender {
    (void)sender;
    [_settingsDelegate settingsControllerDidClear:self];
}

- (void)controlTextDidChange:(NSNotification*)notification {
    (void)notification;
    if (_updating) {
        return;
    }
    NSString* limited = LimitedTitle(_titleField.stringValue, 40);
    if (![limited isEqualToString:_titleField.stringValue]) {
        _titleField.stringValue = limited;
    }
}

- (void)controlTextDidEndEditing:(NSNotification*)notification {
    (void)notification;
    [self commitFromDatePicker:NO];
}

- (void)windowWillClose:(NSNotification*)notification {
    (void)notification;
    if (self.window.firstResponder == _titleField.currentEditor) {
        [self.window makeFirstResponder:nil];
    }
}

@end
