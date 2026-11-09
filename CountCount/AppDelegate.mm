#import "AppDelegate.h"

#import "AboutController.h"
#import "Countdown.hpp"
#import "PopoverController.h"
#import "SettingsController.h"

#include <filesystem>
#include <string>

static const CFTimeInterval kIgnoreCloseAfterOpen = 0.30;
static const CFTimeInterval kIgnoreOpenAfterClose = 0.35;

static NSString* UTF8(const std::string& text) {
    return [NSString stringWithUTF8String:text.c_str()] ?: @"";
}

static std::filesystem::path SupportDirectory() {
    NSFileManager* files = NSFileManager.defaultManager;
    NSURL* base = [files URLForDirectory:NSApplicationSupportDirectory
                                 inDomain:NSUserDomainMask
                        appropriateForURL:nil
                                   create:YES
                                    error:nil];
    NSString* root = base.path;
    if (root.length == 0) {
        root = NSTemporaryDirectory();
    }
    NSString* folder = [root stringByAppendingPathComponent:@"CountCount"];
    [files createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    return std::filesystem::path(folder.fileSystemRepresentation);
}

static NSArray<NSDictionary*>* GoalArray(const std::vector<countcount::Goal>& goals) {
    NSMutableArray<NSDictionary*>* items = [NSMutableArray arrayWithCapacity:goals.size()];
    for (const countcount::Goal& goal : goals) {
        [items addObject:@{
            @"id" : UTF8(goal.id),
            @"title" : UTF8(goal.title),
            @"done" : @(goal.done),
        }];
    }
    return items;
}

static std::optional<std::vector<countcount::Goal>> GoalsFromArray(NSArray<NSDictionary*>* items) {
    if (items == nil) {
        return std::nullopt;
    }
    std::vector<countcount::Goal> goals;
    goals.reserve(items.count);
    for (NSDictionary* item in items) {
        if (![item isKindOfClass:NSDictionary.class]) {
            return std::nullopt;
        }
        NSString* identifier = item[@"id"];
        NSString* title = item[@"title"];
        if (![identifier isKindOfClass:NSString.class] || ![title isKindOfClass:NSString.class]) {
            return std::nullopt;
        }
        countcount::Goal goal;
        const char* idUtf8 = identifier.UTF8String;
        const char* titleUtf8 = title.UTF8String;
        goal.id = idUtf8 ? std::string(idUtf8) : std::string();
        goal.title = titleUtf8 ? std::string(titleUtf8) : std::string();
        goal.done = [item[@"done"] boolValue];
        goals.push_back(std::move(goal));
    }
    return goals;
}

static NSImage* MenuBarIcon(void) {
    NSImage* image = [NSImage imageWithSize:NSMakeSize(16, 16)
                                     flipped:NO
                              drawingHandler:^BOOL(NSRect destination) {
                                  (void)destination;
                                  [[NSColor blackColor] set];

                                  NSBezierPath* body = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(1.0, 1.4, 10.0, 12.2)
                                                                                       xRadius:1.8
                                                                                       yRadius:1.8];
                                  body.lineWidth = 1.35;
                                  body.lineJoinStyle = NSLineJoinStyleRound;
                                  [body stroke];

                                  NSBezierPath* posts = [NSBezierPath bezierPath];
                                  posts.lineWidth = 1.35;
                                  posts.lineCapStyle = NSLineCapStyleRound;
                                  [posts moveToPoint:NSMakePoint(3.5, 12.6)];
                                  [posts lineToPoint:NSMakePoint(3.5, 15.1)];
                                  [posts moveToPoint:NSMakePoint(7.6, 12.6)];
                                  [posts lineToPoint:NSMakePoint(7.6, 15.1)];
                                  [posts stroke];

                                  NSBezierPath* header = [NSBezierPath bezierPath];
                                  header.lineWidth = 1.35;
                                  header.lineCapStyle = NSLineCapStyleRound;
                                  [header moveToPoint:NSMakePoint(1.0, 10.6)];
                                  [header lineToPoint:NSMakePoint(11.0, 10.6)];
                                  [header stroke];

                                  NSBezierPath* arc = [NSBezierPath bezierPath];
                                  arc.lineWidth = 1.45;
                                  arc.lineCapStyle = NSLineCapStyleRound;
                                  [arc appendBezierPathWithArcWithCenter:NSMakePoint(11.1, 4.7)
                                                                   radius:3.25
                                                               startAngle:55
                                                                 endAngle:125
                                                                clockwise:YES];
                                  [arc stroke];
                                  return YES;
                              }];
    [image setTemplate:YES];
    image.accessibilityDescription = @"CountCount";
    return image;
}

@interface AppDelegate () <NSPopoverDelegate, NSStatusItemExpandedInterfaceDelegate, PopoverControllerDelegate,
                            SettingsControllerDelegate>
@end

@implementation AppDelegate {
    NSStatusItem* _statusItem;
    NSPopover* _popover;
    PopoverController* _controller;
    SettingsController* _settings;
    AboutController* _about;
    NSTimer* _midnightTimer;
    NSImage* _menuIcon;
    id _outsideMonitor;
    std::optional<countcount::Store> _store;
    std::optional<countcount::GoalStore> _goalStore;
    BOOL _closingFromSession;
    CFAbsoluteTime _openedAt;
    CFAbsoluteTime _closedAt;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        const std::filesystem::path support = SupportDirectory();
        _store.emplace(support / "event.json");
        _goalStore.emplace(support / "goals.json");
        [NSUserDefaults.standardUserDefaults registerDefaults:@{
            CountCountShowIconKey : @YES,
            CountCountShowTitleKey : @YES,
        }];
    }
    return self;
}

- (void)dealloc {
    [_midnightTimer invalidate];
    [self removeOutsideMonitor];
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    (void)notification;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [self installMainMenu];
    [self installStatusItem];
    [self pushStoredEvent];
    [self pushStoredGoals];
    [self reloadStatus];
    [self scheduleMidnightRefresh];

    NSNotificationCenter* center = NSNotificationCenter.defaultCenter;
    [center addObserver:self
               selector:@selector(clockChanged:)
                   name:NSCalendarDayChangedNotification
                 object:nil];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self
                                                       selector:@selector(clockChanged:)
                                                           name:NSWorkspaceDidWakeNotification
                                                         object:nil];
}

- (void)applicationDidResignActive:(NSNotification*)notification {
    (void)notification;
    [self dismissExpandedInterface];
}

- (void)installMainMenu {
    NSMenu* menuBar = [[NSMenu alloc] init];
    NSMenuItem* appItem = [[NSMenuItem alloc] init];
    NSMenu* appMenu = [[NSMenu alloc] initWithTitle:@"CountCount"];

    NSMenuItem* about = [[NSMenuItem alloc] initWithTitle:@"About CountCount"
                                                   action:@selector(showAbout:)
                                            keyEquivalent:@""];
    about.target = self;
    NSMenuItem* settings = [[NSMenuItem alloc] initWithTitle:@"Settings…"
                                                      action:@selector(showSettings:)
                                               keyEquivalent:@","];
    settings.target = self;
    NSMenuItem* quit = [[NSMenuItem alloc] initWithTitle:@"Quit CountCount"
                                                  action:@selector(terminate:)
                                           keyEquivalent:@"q"];
    quit.target = NSApp;
    [appMenu addItem:about];
    [appMenu addItem:settings];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItem:quit];
    appItem.submenu = appMenu;
    [menuBar addItem:appItem];
    NSApp.mainMenu = menuBar;
}

- (void)installStatusItem {
    _statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.autosaveName = @"CountCountStatusItem";
    _statusItem.behavior = NSStatusItemBehaviorTerminationOnRemoval;
    _statusItem.expandedInterfaceDelegate = self;

    _menuIcon = MenuBarIcon();
    NSStatusBarButton* button = _statusItem.button;
    button.image = _menuIcon;
    button.imagePosition = NSImageLeft;
    button.imageHugsTitle = YES;
    button.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightSemibold];
    button.target = self;
    button.action = @selector(statusButtonClicked:);

    _controller = [[PopoverController alloc] init];
    _controller.delegate = self;
    _popover = [[NSPopover alloc] init];
    _popover.contentViewController = _controller;
    // A Transient popover treats the status-item click as an outside click and
    // closes. The button action then sees a hidden panel and opens it again.
    _popover.behavior = NSPopoverBehaviorApplicationDefined;
    _popover.animates = YES;
    _popover.delegate = self;
}

- (std::optional<countcount::Event>)storedEvent {
    return _store->load();
}

- (void)pushStoredEvent {
    const std::optional<countcount::Event> event = [self storedEvent];
    NSString* title = @"";
    NSInteger year = 0;
    NSInteger month = 0;
    NSInteger day = 0;
    const BOOL configured = event.has_value();
    if (configured) {
        title = UTF8(event->title);
        year = event->date.year;
        month = event->date.month;
        day = event->date.day;
    }
    [_controller setCommittedTitle:title year:year month:month day:day configured:configured];
    [_settings applyTitle:title year:year month:month day:day configured:configured];
}

- (void)pushStoredGoals {
    const std::optional<std::vector<countcount::Goal>> goals = _goalStore->load();
    if (!goals) {
        [_controller showGoalMessage:@"Couldn't read saved goals."];
        return;
    }
    [_controller showGoalMessage:nil];
    [_controller setGoals:GoalArray(*goals)];
}

- (void)reloadStatus {
    NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
    countcount::MenuStyle style;
    style.includeTitle = [defaults boolForKey:CountCountShowTitleKey];
    const countcount::Presentation presentation =
        countcount::present([self storedEvent], countcount::todayLocal(), style);
    NSStatusBarButton* button = _statusItem.button;
    button.title = UTF8(presentation.menuLabel);
    button.toolTip = UTF8(presentation.tooltip);
    button.accessibilityLabel = button.toolTip;
    button.image = [defaults boolForKey:CountCountShowIconKey] ? _menuIcon : nil;
}

- (void)scheduleMidnightRefresh {
    [_midnightTimer invalidate];
    NSCalendar* calendar = NSCalendar.currentCalendar;
    NSDate* start = [calendar startOfDayForDate:[NSDate date]];
    NSDate* next = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:start options:0];
    NSTimeInterval interval = next.timeIntervalSinceNow + 0.5;
    if (interval < 1) {
        interval = 1;
    }
    _midnightTimer = [NSTimer timerWithTimeInterval:interval
                                            target:self
                                          selector:@selector(clockChanged:)
                                          userInfo:nil
                                           repeats:NO];
    [NSRunLoop.mainRunLoop addTimer:_midnightTimer forMode:NSRunLoopCommonModes];
}

- (void)clockChanged:(id)sender {
    (void)sender;
    [self reloadStatus];
    if (_popover.shown) {
        [_controller rerender];
    }
    [self scheduleMidnightRefresh];
}

- (BOOL)recentlyClosed {
    return _closedAt > 0 && CFAbsoluteTimeGetCurrent() - _closedAt < kIgnoreOpenAfterClose;
}

- (BOOL)recentlyOpened {
    return _openedAt > 0 && CFAbsoluteTimeGetCurrent() - _openedAt < kIgnoreCloseAfterOpen;
}

- (void)statusButtonClicked:(id)sender {
    (void)sender;
    if (_popover.shown) {
        if ([self recentlyOpened]) {
            return;
        }
        [self dismissExpandedInterface];
        return;
    }
    if ([self recentlyClosed]) {
        return;
    }
    [self showPopover];
}

- (void)showPopover {
    NSStatusBarButton* button = _statusItem.button;
    if (button == nil || _popover.shown) {
        return;
    }
    [NSApp activate];
    button.highlighted = YES;
    _openedAt = CFAbsoluteTimeGetCurrent();
    [_popover showRelativeToRect:button.bounds ofView:button preferredEdge:NSRectEdgeMinY];
    NSWindow* window = _popover.contentViewController.view.window;
    [window makeKeyWindow];
    [window makeFirstResponder:nil];
    [self installOutsideMonitor];
}

- (void)dismissExpandedInterface {
    if (_statusItem.expandedInterfaceSession == nil && !_popover.shown) {
        return;
    }
    _closedAt = CFAbsoluteTimeGetCurrent();
    _closingFromSession = YES;
    if (_popover.shown) {
        [_popover close];
    }
    _closingFromSession = NO;
    _statusItem.button.highlighted = NO;
    [self removeOutsideMonitor];
    if (_statusItem.expandedInterfaceSession != nil) {
        [_statusItem.expandedInterfaceSession cancel];
    }
}

- (void)statusItem:(NSStatusItem*)statusItem
    didBeginExpandedInterfaceSession:(NSStatusItemExpandedInterfaceSession*)session {
    (void)statusItem;
    if (_popover.shown) {
        return;
    }
    if ([self recentlyClosed]) {
        [session cancel];
        return;
    }
    [self showPopover];
}

- (void)statusItemDidEndExpandedInterfaceSession:(NSStatusItem*)statusItem animated:(BOOL)animated {
    (void)statusItem;
    _closingFromSession = YES;
    _closedAt = CFAbsoluteTimeGetCurrent();
    if (_popover.shown) {
        if (animated) {
            [_popover performClose:nil];
        } else {
            [_popover close];
        }
    }
    _closingFromSession = NO;
    _statusItem.button.highlighted = NO;
    [self removeOutsideMonitor];
}

- (void)popoverDidClose:(NSNotification*)notification {
    (void)notification;
    _statusItem.button.highlighted = NO;
    [self removeOutsideMonitor];
    _closedAt = CFAbsoluteTimeGetCurrent();
    if (!_closingFromSession && _statusItem.expandedInterfaceSession != nil) {
        [_statusItem.expandedInterfaceSession cancel];
    }
}

- (BOOL)eventIsOnStatusButton:(NSEvent*)event {
    NSStatusBarButton* button = _statusItem.button;
    if (button == nil || button.window == nil) {
        return NO;
    }
    if (event.window == button.window) {
        return YES;
    }
    NSPoint screenPoint = event.window != nil ? [event.window convertPointToScreen:event.locationInWindow]
                                              : event.locationInWindow;
    NSRect rect = [button convertRect:button.bounds toView:nil];
    rect = [button.window convertRectToScreen:rect];
    rect = NSInsetRect(rect, -6, -6);
    return NSPointInRect(screenPoint, rect);
}

- (BOOL)eventIsInsidePopover:(NSEvent*)event {
    NSWindow* window = _controller.view.window;
    if (window == nil) {
        return NO;
    }
    if (event.window == window) {
        return YES;
    }
    NSPoint screenPoint = event.window != nil ? [event.window convertPointToScreen:event.locationInWindow]
                                              : event.locationInWindow;
    return NSPointInRect(screenPoint, window.frame);
}

- (void)installOutsideMonitor {
    if (_outsideMonitor != nil) {
        return;
    }
    NSEventMask mask = NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown | NSEventMaskOtherMouseDown |
                       NSEventMaskKeyDown;
    _outsideMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:mask
                                                             handler:^NSEvent*(NSEvent* event) {
                                                                 if (!self->_popover.shown) {
                                                                     return event;
                                                                 }
                                                                 if (event.type == NSEventTypeKeyDown) {
                                                                     if (event.keyCode == 53) {
                                                                         [self dismissExpandedInterface];
                                                                         return nil;
                                                                     }
                                                                     return event;
                                                                 }
                                                                 if ([self eventIsOnStatusButton:event] ||
                                                                     [self eventIsInsidePopover:event]) {
                                                                     return event;
                                                                 }
                                                                 [self dismissExpandedInterface];
                                                                 return event;
                                                             }];
}

- (void)removeOutsideMonitor {
    if (_outsideMonitor == nil) {
        return;
    }
    [NSEvent removeMonitor:_outsideMonitor];
    _outsideMonitor = nil;
}

- (BOOL)saveEventTitle:(NSString*)title year:(NSInteger)year month:(NSInteger)month day:(NSInteger)day {
    countcount::Event event;
    const char* utf8 = title.UTF8String;
    event.title = utf8 ? std::string(utf8) : std::string();
    event.date = countcount::CivilDate {static_cast<int>(year), static_cast<int>(month), static_cast<int>(day)};
    if (!_store->save(event)) {
        return NO;
    }
    [self reloadStatus];
    [self pushStoredEvent];
    return YES;
}

- (BOOL)clearStoredEvent {
    if (!_store->clear()) {
        return NO;
    }
    [self reloadStatus];
    [self pushStoredEvent];
    return YES;
}

- (void)settingsController:(SettingsController*)controller
            didCommitTitle:(NSString*)title
                      year:(NSInteger)year
                     month:(NSInteger)month
                       day:(NSInteger)day {
    if (![self saveEventTitle:title year:year month:month day:day]) {
        [controller showMessage:@"Couldn't save. Check the available disk space."];
    }
}

- (void)settingsControllerDidClear:(SettingsController*)controller {
    if (![self clearStoredEvent]) {
        [controller showMessage:@"Couldn't clear the saved date."];
    }
}

- (void)settingsControllerDidChangeDisplay:(SettingsController*)controller {
    (void)controller;
    [self reloadStatus];
}

- (void)popoverControllerDidClear:(PopoverController*)controller {
    if (![self clearStoredEvent]) {
        [controller showMessage:@"Couldn't clear the saved date."];
    }
}

- (void)popoverControllerDidQuit:(PopoverController*)controller {
    (void)controller;
    [NSApp terminate:nil];
}

- (void)popoverControllerDidRequestSettings:(PopoverController*)controller {
    (void)controller;
    [self showSettings:nil];
}

- (void)popoverControllerDidRequestAbout:(PopoverController*)controller {
    (void)controller;
    [self showAbout:nil];
}

- (BOOL)popoverController:(PopoverController*)controller didChangeGoals:(NSArray<NSDictionary*>*)goals {
    const std::optional<std::vector<countcount::Goal>> parsed = GoalsFromArray(goals);
    if (!parsed || !_goalStore->save(*parsed)) {
        [controller showGoalMessage:@"Couldn't save goals."];
        return NO;
    }
    [self pushStoredGoals];
    return YES;
}

- (void)showSettings:(id)sender {
    (void)sender;
    [self dismissExpandedInterface];
    if (_settings == nil) {
        _settings = [[SettingsController alloc] initWithDelegate:self];
    }
    [self pushStoredEvent];
    [NSApp activate];
    _settings.window.hidesOnDeactivate = NO;
    [_settings showWindow:self];
    [_settings.window orderFrontRegardless];
    [_settings.window makeKeyAndOrderFront:nil];
}

- (void)showAbout:(id)sender {
    (void)sender;
    [self dismissExpandedInterface];
    if (_about == nil) {
        _about = [[AboutController alloc] init];
    }
    [NSApp activate];
    _about.window.hidesOnDeactivate = NO;
    [_about showWindow:self];
    [_about.window orderFrontRegardless];
    [_about.window makeKeyAndOrderFront:nil];
}

@end
