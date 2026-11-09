#import "HelpController.h"

static const CGFloat kHelpWidth = 420;

static NSTextField* HelpHeading(NSString* text) {
    NSTextField* label = [NSTextField wrappingLabelWithString:text];
    label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    label.textColor = NSColor.labelColor;
    [label.widthAnchor constraintEqualToConstant:kHelpWidth].active = YES;
    return label;
}

static NSTextField* HelpBody(NSString* text) {
    NSTextField* label = [NSTextField wrappingLabelWithString:text];
    label.font = [NSFont systemFontOfSize:13];
    label.textColor = NSColor.secondaryLabelColor;
    [label.widthAnchor constraintEqualToConstant:kHelpWidth].active = YES;
    return label;
}

@implementation HelpController

- (instancetype)init {
    NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 468, 560)
                                                    styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskMiniaturizable
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
    self = [super initWithWindow:window];
    if (self == nil) {
        return nil;
    }
    window.title = @"CountCount Help";
    window.releasedWhenClosed = NO;
    window.hidesOnDeactivate = NO;
    window.level = NSFloatingWindowLevel;
    window.collectionBehavior = NSWindowCollectionBehaviorMoveToActiveSpace |
                                NSWindowCollectionBehaviorFullScreenAuxiliary;
    [self buildContentInWindow:window];
    [window center];
    return self;
}

- (void)buildContentInWindow:(NSWindow*)window {
    NSView* root = window.contentView;
    NSStackView* stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 6;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    NSArray<NSArray<NSString*>*>* sections = @[
        @[@"CountCount keeps one goal in the menu bar and counts the days until that date."],
        @[
            @"See your goal",
            @"Click the menu bar icon. The panel shows the goal, the days left, and the date. Click the icon again to close the panel. Clicking outside it, or pressing Escape, closes it too.",
        ],
        @[
            @"Set a goal",
            @"Choose Settings… and enter a name, such as a launch or a birthday. Pick the date. Changes save automatically. Clear removes the goal.",
        ],
        @[
            @"Menu bar",
            @"Show icon and Show goal name choose what appears next to the day count.",
        ],
        @[
            @"Reading the count",
            @"A future date shows the days left. On the day itself, the panel says Today. After the date, it shows how many days have passed.",
        ],
        @[
            @"Quit",
            @"Choose Quit in the panel, or press Command-Q while CountCount is active.",
        ],
    ];

    for (NSArray<NSString*>* section in sections) {
        if (section.count == 1) {
            [stack addArrangedSubview:HelpBody(section[0])];
            [stack setCustomSpacing:16 afterView:stack.arrangedSubviews.lastObject];
            continue;
        }
        NSTextField* heading = HelpHeading(section[0]);
        [stack addArrangedSubview:heading];
        [stack setCustomSpacing:2 afterView:heading];
        NSTextField* body = HelpBody(section[1]);
        [stack addArrangedSubview:body];
        [stack setCustomSpacing:14 afterView:body];
    }

    [root addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:root.topAnchor constant:20],
        [stack.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],
        [stack.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-20],
        [stack.widthAnchor constraintEqualToConstant:kHelpWidth],
    ]];
    [root layoutSubtreeIfNeeded];
    const NSSize fitting = [stack fittingSize];
    [window setContentSize:NSMakeSize(fitting.width + 48, fitting.height + 40)];
}

@end
