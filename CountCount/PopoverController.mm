#import "PopoverController.h"

#import "Countdown.hpp"

static const CGFloat kContentWidth = 300;
static const CGFloat kGoalListMaxHeight = 168;

static NSString* UTF8(const std::string& text) {
    return [NSString stringWithUTF8String:text.c_str()] ?: @"";
}

static NSString* Trimmed(NSString* text) {
    return [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
}

static NSTextField* CenteredLabel(NSFont* font, NSColor* color) {
    NSTextField* label = [NSTextField labelWithString:@""];
    label.font = font;
    label.textColor = color;
    label.alignment = NSTextAlignmentCenter;
    label.maximumNumberOfLines = 2;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.cell.wraps = YES;
    label.cell.scrollable = NO;
    [label.widthAnchor constraintEqualToConstant:kContentWidth].active = YES;
    return label;
}

@interface GoalListDocument : NSView
@end

@implementation GoalListDocument
- (BOOL)isFlipped {
    return YES;
}
@end

@implementation PopoverController {
    NSStackView* _stack;
    NSTextField* _kickerLabel;
    NSTextField* _headlineLabel;
    NSTextField* _unitLabel;
    NSTextField* _dateLabel;
    NSScrollView* _goalScroll;
    GoalListDocument* _goalDocument;
    NSStackView* _goalRows;
    NSLayoutConstraint* _goalScrollHeight;
    NSTextField* _emptyGoalsLabel;
    NSTextField* _goalField;
    NSTextField* _goalMessage;
    NSButton* _clearButton;
    NSButton* _settingsButton;
    NSArray<NSDictionary*>* _goals;
    NSString* _message;
    NSString* _title;
    NSInteger _year;
    NSInteger _month;
    NSInteger _day;
    BOOL _configured;
}

- (void)loadView {
    _title = @"";
    _goals = @[];
    NSView* root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 336, 420)];
    _stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    _stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    _stack.alignment = NSLayoutAttributeLeading;
    _stack.spacing = 8;
    _stack.detachesHiddenViews = YES;
    _stack.translatesAutoresizingMaskIntoConstraints = NO;

    [_stack addArrangedSubview:[self headerRow]];
    [_stack setCustomSpacing:16 afterView:_stack.arrangedSubviews.lastObject];

    _kickerLabel = CenteredLabel([NSFont systemFontOfSize:13], NSColor.labelColor);
    _headlineLabel = CenteredLabel([NSFont monospacedDigitSystemFontOfSize:48 weight:NSFontWeightMedium],
                                   NSColor.labelColor);
    _headlineLabel.maximumNumberOfLines = 1;
    _unitLabel = CenteredLabel([NSFont systemFontOfSize:13 weight:NSFontWeightMedium],
                               NSColor.secondaryLabelColor);
    _dateLabel = CenteredLabel([NSFont systemFontOfSize:12], NSColor.secondaryLabelColor);
    NSStackView* hero = [NSStackView stackViewWithViews:@[_kickerLabel, _headlineLabel, _unitLabel, _dateLabel]];
    hero.orientation = NSUserInterfaceLayoutOrientationVertical;
    hero.alignment = NSLayoutAttributeCenterX;
    hero.spacing = 0;
    hero.detachesHiddenViews = YES;
    [hero setCustomSpacing:2 afterView:_kickerLabel];
    [hero setCustomSpacing:6 afterView:_unitLabel];
    [hero.widthAnchor constraintEqualToConstant:kContentWidth].active = YES;
    [_stack addArrangedSubview:hero];
    [_stack setCustomSpacing:14 afterView:hero];

    [_stack addArrangedSubview:[self separator]];
    [_stack setCustomSpacing:10 afterView:_stack.arrangedSubviews.lastObject];
    [_stack addArrangedSubview:[self goalsSection]];
    [_stack setCustomSpacing:12 afterView:_stack.arrangedSubviews.lastObject];
    [_stack addArrangedSubview:[self separator]];
    [_stack setCustomSpacing:12 afterView:_stack.arrangedSubviews.lastObject];
    [_stack addArrangedSubview:[self buttonRow]];

    [root addSubview:_stack];
    [NSLayoutConstraint activateConstraints:@[
        [_stack.topAnchor constraintEqualToAnchor:root.topAnchor constant:18],
        [_stack.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:18],
        [_stack.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-18],
        [_stack.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-16],
        [_stack.widthAnchor constraintEqualToConstant:kContentWidth],
    ]];
    self.view = root;
    [self render];
    [self rebuildGoalRows];
}

- (NSBox*)separator {
    NSBox* rule = [[NSBox alloc] initWithFrame:NSZeroRect];
    rule.boxType = NSBoxSeparator;
    rule.translatesAutoresizingMaskIntoConstraints = NO;
    [rule.widthAnchor constraintEqualToConstant:kContentWidth].active = YES;
    return rule;
}

- (NSView*)headerRow {
    NSImage* icon = [NSImage imageNamed:NSImageNameApplicationIcon];
    NSImageView* iconView = [NSImageView imageViewWithImage:icon];
    iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    [iconView.widthAnchor constraintEqualToConstant:40].active = YES;
    [iconView.heightAnchor constraintEqualToConstant:40].active = YES;

    NSTextField* name = [NSTextField labelWithString:@"CountCount"];
    name.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
    NSTextField* tagline = [NSTextField labelWithString:@"Menu bar countdown"];
    tagline.font = [NSFont systemFontOfSize:12];
    tagline.textColor = NSColor.secondaryLabelColor;
    NSStackView* titles = [NSStackView stackViewWithViews:@[name, tagline]];
    titles.orientation = NSUserInterfaceLayoutOrientationVertical;
    titles.alignment = NSLayoutAttributeLeading;
    titles.spacing = 1;

    NSStackView* header = [NSStackView stackViewWithViews:@[iconView, titles]];
    header.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    header.alignment = NSLayoutAttributeCenterY;
    header.spacing = 10;
    [header.widthAnchor constraintEqualToConstant:kContentWidth].active = YES;
    return header;
}

- (NSView*)goalsSection {
    NSTextField* caption = [NSTextField labelWithString:@"Goals"];
    caption.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    caption.textColor = NSColor.secondaryLabelColor;

    _emptyGoalsLabel = [NSTextField labelWithString:@"No goals yet."];
    _emptyGoalsLabel.font = [NSFont systemFontOfSize:13];
    _emptyGoalsLabel.textColor = NSColor.tertiaryLabelColor;
    [_emptyGoalsLabel.widthAnchor constraintEqualToConstant:kContentWidth].active = YES;

    _goalRows = [[NSStackView alloc] initWithFrame:NSZeroRect];
    _goalRows.orientation = NSUserInterfaceLayoutOrientationVertical;
    _goalRows.alignment = NSLayoutAttributeLeading;
    _goalRows.spacing = 2;
    _goalRows.translatesAutoresizingMaskIntoConstraints = NO;

    _goalDocument = [[GoalListDocument alloc] initWithFrame:NSMakeRect(0, 0, kContentWidth, 1)];
    [_goalDocument addSubview:_goalRows];
    [NSLayoutConstraint activateConstraints:@[
        [_goalRows.topAnchor constraintEqualToAnchor:_goalDocument.topAnchor],
        [_goalRows.leadingAnchor constraintEqualToAnchor:_goalDocument.leadingAnchor],
        [_goalRows.trailingAnchor constraintEqualToAnchor:_goalDocument.trailingAnchor],
        [_goalRows.widthAnchor constraintEqualToConstant:kContentWidth],
    ]];

    _goalScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    _goalScroll.drawsBackground = NO;
    _goalScroll.borderType = NSNoBorder;
    _goalScroll.hasVerticalScroller = YES;
    _goalScroll.autohidesScrollers = YES;
    _goalScroll.documentView = _goalDocument;
    _goalScroll.translatesAutoresizingMaskIntoConstraints = NO;
    [_goalScroll.widthAnchor constraintEqualToConstant:kContentWidth].active = YES;
    _goalScrollHeight = [_goalScroll.heightAnchor constraintEqualToConstant:1];
    _goalScrollHeight.active = YES;

    _goalField = [NSTextField textFieldWithString:@""];
    _goalField.placeholderString = @"Add a goal";
    _goalField.font = [NSFont systemFontOfSize:13];
    _goalField.target = self;
    _goalField.action = @selector(addGoalPressed:);
    _goalField.translatesAutoresizingMaskIntoConstraints = NO;
    [_goalField setContentHuggingPriority:NSLayoutPriorityDefaultLow
                            forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSButton* add = [NSButton buttonWithTitle:@"Add" target:self action:@selector(addGoalPressed:)];
    add.bezelStyle = NSBezelStyleRounded;
    add.controlSize = NSControlSizeSmall;
    [add setContentHuggingPriority:NSLayoutPriorityRequired
                     forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSStackView* addRow = [NSStackView stackViewWithViews:@[_goalField, add]];
    addRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    addRow.alignment = NSLayoutAttributeCenterY;
    addRow.spacing = 8;
    [addRow.widthAnchor constraintEqualToConstant:kContentWidth].active = YES;

    _goalMessage = [NSTextField wrappingLabelWithString:@""];
    _goalMessage.font = [NSFont systemFontOfSize:12];
    _goalMessage.textColor = NSColor.systemRedColor;
    _goalMessage.hidden = YES;
    [_goalMessage.widthAnchor constraintEqualToConstant:kContentWidth].active = YES;

    NSStackView* section = [NSStackView stackViewWithViews:@[caption, _emptyGoalsLabel, _goalScroll, addRow, _goalMessage]];
    section.orientation = NSUserInterfaceLayoutOrientationVertical;
    section.alignment = NSLayoutAttributeLeading;
    section.spacing = 6;
    section.detachesHiddenViews = YES;
    [section setCustomSpacing:4 afterView:caption];
    [section.widthAnchor constraintEqualToConstant:kContentWidth].active = YES;
    return section;
}

- (NSView*)buttonRow {
    NSButton* quit = [NSButton buttonWithTitle:@"Quit" target:self action:@selector(quitPressed:)];
    quit.bezelStyle = NSBezelStyleRounded;
    quit.controlSize = NSControlSizeSmall;

    NSButton* about = [NSButton buttonWithTitle:@"About" target:self action:@selector(aboutPressed:)];
    about.bezelStyle = NSBezelStyleRounded;
    about.controlSize = NSControlSizeSmall;

    _clearButton = [NSButton buttonWithTitle:@"Clear" target:self action:@selector(clearPressed:)];
    _clearButton.bezelStyle = NSBezelStyleRounded;
    _clearButton.controlSize = NSControlSizeSmall;

    _settingsButton = [NSButton buttonWithTitle:@"Settings…" target:self action:@selector(settingsPressed:)];
    _settingsButton.bezelStyle = NSBezelStyleRounded;
    _settingsButton.controlSize = NSControlSizeRegular;

    NSView* spacer = [[NSView alloc] initWithFrame:NSZeroRect];
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow
                        forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView* row = [NSStackView stackViewWithViews:@[quit, about, spacer, _clearButton, _settingsButton]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 8;
    row.detachesHiddenViews = YES;
    [row.widthAnchor constraintEqualToConstant:kContentWidth].active = YES;
    return row;
}

- (NSView*)rowForGoal:(NSDictionary*)goal {
    NSString* title = goal[@"title"];
    if (![title isKindOfClass:NSString.class]) {
        title = @"";
    }
    NSString* goalID = goal[@"id"];
    if (![goalID isKindOfClass:NSString.class]) {
        goalID = @"";
    }
    const BOOL done = [goal[@"done"] boolValue];

    NSButton* box = [NSButton checkboxWithTitle:title target:self action:@selector(goalToggled:)];
    box.font = [NSFont systemFontOfSize:13];
    box.state = done ? NSControlStateValueOn : NSControlStateValueOff;
    box.identifier = goalID;
    box.lineBreakMode = NSLineBreakByTruncatingTail;
    [box setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                   forOrientation:NSLayoutConstraintOrientationHorizontal];
    [box setContentHuggingPriority:NSLayoutPriorityDefaultLow
                     forOrientation:NSLayoutConstraintOrientationHorizontal];
    if (done && title.length > 0) {
        NSMutableAttributedString* struck = [[NSMutableAttributedString alloc] initWithString:title];
        const NSRange range = NSMakeRange(0, title.length);
        [struck addAttribute:NSStrikethroughStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
        [struck addAttribute:NSForegroundColorAttributeName value:NSColor.secondaryLabelColor range:range];
        [struck addAttribute:NSFontAttributeName value:box.font range:range];
        box.attributedTitle = struck;
    }

    NSButton* remove = [NSButton buttonWithTitle:@"Remove" target:self action:@selector(removeGoalPressed:)];
    remove.bezelStyle = NSBezelStyleRounded;
    remove.controlSize = NSControlSizeSmall;
    remove.identifier = goalID;
    remove.translatesAutoresizingMaskIntoConstraints = NO;
    [remove setContentHuggingPriority:NSLayoutPriorityRequired
                         forOrientation:NSLayoutConstraintOrientationHorizontal];

    box.translatesAutoresizingMaskIntoConstraints = NO;
    [box setContentHuggingPriority:NSLayoutPriorityDefaultLow
                     forOrientation:NSLayoutConstraintOrientationHorizontal];
    [box setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                   forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSView* row = [[NSView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:box];
    [row addSubview:remove];
    [NSLayoutConstraint activateConstraints:@[
        [row.widthAnchor constraintEqualToConstant:kContentWidth],
        [box.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [box.topAnchor constraintEqualToAnchor:row.topAnchor],
        [box.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [box.trailingAnchor constraintLessThanOrEqualToAnchor:remove.leadingAnchor constant:-8],
        [remove.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [remove.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    return row;
}

- (void)rebuildGoalRows {
    NSArray<NSView*>* existing = [_goalRows.arrangedSubviews copy];
    for (NSView* view in existing) {
        [_goalRows removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    const BOOL empty = _goals.count == 0;
    _emptyGoalsLabel.hidden = !empty;
    _goalScroll.hidden = empty;
    if (!empty) {
        for (NSDictionary* goal in _goals) {
            [_goalRows addArrangedSubview:[self rowForGoal:goal]];
        }
        [_goalRows layoutSubtreeIfNeeded];
        const CGFloat contentHeight = MAX(_goalRows.fittingSize.height, 1);
        _goalDocument.frame = NSMakeRect(0, 0, kContentWidth, contentHeight);
        _goalScrollHeight.constant = MIN(kGoalListMaxHeight, contentHeight);
    }
    [self relayout];
}

- (void)setCommittedTitle:(NSString*)title
                     year:(NSInteger)year
                    month:(NSInteger)month
                      day:(NSInteger)day
               configured:(BOOL)configured {
    (void)self.view;
    _title = title ?: @"";
    _year = year;
    _month = month;
    _day = day;
    _configured = configured;
    _message = nil;
    [self render];
}

- (void)setGoals:(NSArray<NSDictionary*>*)goals {
    (void)self.view;
    _goals = [goals copy] ?: @[];
    [self rebuildGoalRows];
}

- (void)rerender {
    (void)self.view;
    [self render];
}

- (void)showMessage:(NSString*)message {
    (void)self.view;
    _message = [message copy];
    [self render];
}

- (void)showGoalMessage:(NSString*)message {
    (void)self.view;
    _goalMessage.stringValue = message ?: @"";
    _goalMessage.hidden = _goalMessage.stringValue.length == 0;
    [self relayout];
}

- (void)render {
    std::optional<countcount::Event> event;
    if (_configured) {
        countcount::Event stored;
        const char* utf8 = _title.UTF8String;
        stored.title = utf8 ? std::string(utf8) : std::string();
        stored.date = countcount::CivilDate {static_cast<int>(_year), static_cast<int>(_month),
                                             static_cast<int>(_day)};
        event = stored;
    }
    const countcount::Presentation presentation = countcount::present(event, countcount::todayLocal());
    if (_message.length > 0) {
        _kickerLabel.stringValue = _message;
        _kickerLabel.textColor = NSColor.systemRedColor;
        _kickerLabel.hidden = NO;
    } else {
        _kickerLabel.stringValue = UTF8(presentation.kicker);
        _kickerLabel.textColor = NSColor.labelColor;
        _kickerLabel.hidden = presentation.kicker.empty();
    }
    _headlineLabel.stringValue = UTF8(presentation.headline);
    const BOOL compactNumber = _headlineLabel.stringValue.length >= 6;
    _headlineLabel.font = [NSFont monospacedDigitSystemFontOfSize:compactNumber ? 36 : 48
                                                           weight:NSFontWeightMedium];
    if (!presentation.configured) {
        _headlineLabel.textColor = NSColor.tertiaryLabelColor;
    } else if (presentation.dayDelta == 0) {
        _headlineLabel.textColor = NSColor.systemOrangeColor;
    } else if (presentation.dayDelta < 0) {
        _headlineLabel.textColor = NSColor.secondaryLabelColor;
    } else {
        _headlineLabel.textColor = NSColor.labelColor;
    }
    _unitLabel.stringValue = UTF8(presentation.unit);
    _unitLabel.hidden = presentation.unit.empty();
    _dateLabel.stringValue = UTF8(presentation.dateLine);
    _dateLabel.hidden = presentation.dateLine.empty();
    _clearButton.hidden = !_configured;
    _settingsButton.title = _configured ? @"Settings…" : @"Choose Date";
    _settingsButton.keyEquivalent = _configured ? @"" : @"\r";
    [self relayout];
}

- (void)relayout {
    [self.view layoutSubtreeIfNeeded];
    const CGFloat height = _stack.fittingSize.height + 18 + 16;
    const NSSize size = NSMakeSize(kContentWidth + 36, MAX(height, 220));
    if (!NSEqualSizes(self.preferredContentSize, size)) {
        self.preferredContentSize = size;
        self.view.frame = NSMakeRect(0, 0, size.width, size.height);
    }
}

- (BOOL)commitGoals:(NSArray<NSDictionary*>*)goals {
    return [self.delegate popoverController:self didChangeGoals:goals];
}

- (void)addGoalPressed:(id)sender {
    (void)sender;
    NSString* title = Trimmed(_goalField.stringValue);
    if (title.length == 0) {
        return;
    }
    NSMutableArray<NSDictionary*>* next = [_goals mutableCopy];
    [next addObject:@{
        @"id" : [NSUUID UUID].UUIDString,
        @"title" : title,
        @"done" : @NO,
    }];
    if ([self commitGoals:next]) {
        _goalField.stringValue = @"";
    }
}

- (void)goalToggled:(NSButton*)sender {
    NSString* goalID = sender.identifier;
    const BOOL done = sender.state == NSControlStateValueOn;
    NSMutableArray<NSDictionary*>* next = [NSMutableArray arrayWithCapacity:_goals.count];
    for (NSDictionary* goal in _goals) {
        if ([goal[@"id"] isEqual:goalID]) {
            NSMutableDictionary* updated = [goal mutableCopy];
            updated[@"done"] = @(done);
            [next addObject:updated];
        } else {
            [next addObject:goal];
        }
    }
    if (![self commitGoals:next]) {
        [self rebuildGoalRows];
    }
}

- (void)removeGoalPressed:(NSButton*)sender {
    NSString* goalID = sender.identifier;
    NSMutableArray<NSDictionary*>* next = [NSMutableArray array];
    for (NSDictionary* goal in _goals) {
        if (![goal[@"id"] isEqual:goalID]) {
            [next addObject:goal];
        }
    }
    if (![self commitGoals:next]) {
        [self rebuildGoalRows];
    }
}

- (void)settingsPressed:(id)sender {
    (void)sender;
    [self.delegate popoverControllerDidRequestSettings:self];
}

- (void)aboutPressed:(id)sender {
    (void)sender;
    [self.delegate popoverControllerDidRequestAbout:self];
}

- (void)clearPressed:(id)sender {
    (void)sender;
    [self.delegate popoverControllerDidClear:self];
}

- (void)quitPressed:(id)sender {
    (void)sender;
    [self.delegate popoverControllerDidQuit:self];
}

@end
