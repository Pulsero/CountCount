#import "PopoverController.h"

#import "Countdown.hpp"

static const CGFloat kContentWidth = 300;

static NSString* UTF8(const std::string& text) {
    return [NSString stringWithUTF8String:text.c_str()] ?: @"";
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

@implementation PopoverController {
    NSStackView* _stack;
    NSTextField* _goalLabel;
    NSTextField* _kickerLabel;
    NSTextField* _headlineLabel;
    NSTextField* _unitLabel;
    NSTextField* _dateLabel;
    NSButton* _clearButton;
    NSButton* _settingsButton;
    NSString* _message;
    NSString* _title;
    NSInteger _year;
    NSInteger _month;
    NSInteger _day;
    BOOL _configured;
}

- (void)loadView {
    _title = @"";
    NSView* root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 336, 280)];
    _stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    _stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    _stack.alignment = NSLayoutAttributeLeading;
    _stack.spacing = 8;
    _stack.detachesHiddenViews = YES;
    _stack.translatesAutoresizingMaskIntoConstraints = NO;

    [_stack addArrangedSubview:[self headerRow]];
    [_stack setCustomSpacing:16 afterView:_stack.arrangedSubviews.lastObject];
    NSTextField* goalCaption = CenteredLabel([NSFont systemFontOfSize:12 weight:NSFontWeightSemibold],
                                             NSColor.secondaryLabelColor);
    goalCaption.stringValue = @"Goal";
    goalCaption.maximumNumberOfLines = 1;
    _goalLabel = CenteredLabel([NSFont systemFontOfSize:20 weight:NSFontWeightSemibold], NSColor.labelColor);
    _kickerLabel = CenteredLabel([NSFont systemFontOfSize:13], NSColor.labelColor);
    [_stack addArrangedSubview:goalCaption];
    [_stack setCustomSpacing:2 afterView:goalCaption];
    [_stack addArrangedSubview:_goalLabel];
    [_stack setCustomSpacing:10 afterView:_goalLabel];
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

    NSBox* rule = [[NSBox alloc] initWithFrame:NSZeroRect];
    rule.boxType = NSBoxSeparator;
    rule.translatesAutoresizingMaskIntoConstraints = NO;
    [rule.widthAnchor constraintEqualToConstant:kContentWidth].active = YES;
    [_stack addArrangedSubview:rule];
    [_stack setCustomSpacing:12 afterView:rule];
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

- (NSView*)buttonRow {
    NSButton* quit = [NSButton buttonWithTitle:@"Quit" target:self action:@selector(quitPressed:)];
    quit.bezelStyle = NSBezelStyleRounded;
    quit.controlSize = NSControlSizeSmall;

    NSButton* help = [NSButton buttonWithTitle:@"Help" target:self action:@selector(helpPressed:)];
    help.bezelStyle = NSBezelStyleRounded;
    help.controlSize = NSControlSizeSmall;

    _clearButton = [NSButton buttonWithTitle:@"Clear" target:self action:@selector(clearPressed:)];
    _clearButton.bezelStyle = NSBezelStyleRounded;
    _clearButton.controlSize = NSControlSizeSmall;

    _settingsButton = [NSButton buttonWithTitle:@"Settings…" target:self action:@selector(settingsPressed:)];
    _settingsButton.bezelStyle = NSBezelStyleRounded;
    _settingsButton.controlSize = NSControlSizeRegular;

    NSView* spacer = [[NSView alloc] initWithFrame:NSZeroRect];
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow
                        forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView* row = [NSStackView stackViewWithViews:@[quit, help, spacer, _clearButton, _settingsButton]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 8;
    row.detachesHiddenViews = YES;
    [row.widthAnchor constraintEqualToConstant:kContentWidth].active = YES;
    return row;
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

- (void)rerender {
    (void)self.view;
    [self render];
}

- (void)showMessage:(NSString*)message {
    (void)self.view;
    _message = [message copy];
    [self render];
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
    NSString* goal = [_title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!_configured) {
        _goalLabel.stringValue = @"Not set";
        _goalLabel.textColor = NSColor.tertiaryLabelColor;
    } else if (goal.length == 0) {
        _goalLabel.stringValue = @"Untitled";
        _goalLabel.textColor = NSColor.secondaryLabelColor;
    } else {
        _goalLabel.stringValue = goal;
        _goalLabel.textColor = NSColor.labelColor;
    }
    if (_message.length > 0) {
        _kickerLabel.stringValue = _message;
        _kickerLabel.textColor = NSColor.systemRedColor;
        _kickerLabel.hidden = NO;
    } else {
        _kickerLabel.stringValue = @"";
        _kickerLabel.hidden = YES;
    }
    _headlineLabel.hidden = !presentation.configured;
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
    const NSSize size = NSMakeSize(kContentWidth + 36, MAX(height, 180));
    if (!NSEqualSizes(self.preferredContentSize, size)) {
        self.preferredContentSize = size;
        self.view.frame = NSMakeRect(0, 0, size.width, size.height);
    }
}

- (void)settingsPressed:(id)sender {
    (void)sender;
    [self.delegate popoverControllerDidRequestSettings:self];
}

- (void)helpPressed:(id)sender {
    (void)sender;
    [self.delegate popoverControllerDidRequestHelp:self];
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
