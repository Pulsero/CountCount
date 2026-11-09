#import "AboutController.h"

static const CGFloat kAboutWidth = 320;

static NSTextField* AboutLabel(NSString* text, NSFont* font, NSColor* color) {
    NSTextField* label = [NSTextField wrappingLabelWithString:text];
    label.font = font;
    label.textColor = color;
    label.alignment = NSTextAlignmentCenter;
    [label.widthAnchor constraintEqualToConstant:kAboutWidth].active = YES;
    return label;
}

@implementation AboutController

- (instancetype)init {
    NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 380, 320)
                                                    styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskMiniaturizable
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
    self = [super initWithWindow:window];
    if (self == nil) {
        return nil;
    }
    window.title = @"About CountCount";
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
    NSImage* icon = [NSImage imageNamed:NSImageNameApplicationIcon];
    NSImageView* iconView = [NSImageView imageViewWithImage:icon];
    iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    [iconView.widthAnchor constraintEqualToConstant:72].active = YES;
    [iconView.heightAnchor constraintEqualToConstant:72].active = YES;

    NSString* version = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];
    if (version.length == 0) {
        version = @"1.0";
    }
    NSString* copyright = NSBundle.mainBundle.infoDictionary[@"NSHumanReadableCopyright"];
    if (copyright.length == 0) {
        copyright = @"Copyright (C) 2026 CountCount";
    }

    NSStackView* stack = [NSStackView stackViewWithViews:@[
        iconView,
        AboutLabel(@"CountCount", [NSFont systemFontOfSize:20 weight:NSFontWeightSemibold], NSColor.labelColor),
        AboutLabel([@"Version " stringByAppendingString:version], [NSFont systemFontOfSize:13],
                   NSColor.secondaryLabelColor),
        AboutLabel(@"Counts the days until a date, in the menu bar.", [NSFont systemFontOfSize:13],
                   NSColor.labelColor),
        AboutLabel(copyright, [NSFont systemFontOfSize:12], NSColor.tertiaryLabelColor),
    ]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeCenterX;
    stack.spacing = 6;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [stack setCustomSpacing:12 afterView:iconView];
    [stack setCustomSpacing:14 afterView:stack.arrangedSubviews[3]];

    [root addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:root.topAnchor constant:24],
        [stack.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24],
        [stack.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-24],
        [stack.widthAnchor constraintEqualToConstant:kAboutWidth],
    ]];
    [root layoutSubtreeIfNeeded];
    const NSSize fitting = [stack fittingSize];
    [window setContentSize:NSMakeSize(fitting.width + 48, fitting.height + 48)];
}

@end
