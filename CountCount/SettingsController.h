#import <AppKit/AppKit.h>

@class SettingsController;

extern NSString * const CountCountShowIconKey;
extern NSString * const CountCountShowTitleKey;

@protocol SettingsControllerDelegate <NSObject>
- (void)settingsController:(SettingsController *)controller
            didCommitTitle:(NSString *)title
                      year:(NSInteger)year
                     month:(NSInteger)month
                       day:(NSInteger)day;
- (void)settingsControllerDidClear:(SettingsController *)controller;
- (void)settingsControllerDidChangeDisplay:(SettingsController *)controller;
@end

@interface SettingsController : NSWindowController
- (instancetype)initWithDelegate:(id<SettingsControllerDelegate>)delegate;
- (void)applyTitle:(NSString *)title
              year:(NSInteger)year
             month:(NSInteger)month
               day:(NSInteger)day
        configured:(BOOL)configured;
- (void)showMessage:(NSString *)message;
@end
