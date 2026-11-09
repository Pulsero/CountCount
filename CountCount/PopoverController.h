#import <AppKit/AppKit.h>

@class PopoverController;

@protocol PopoverControllerDelegate <NSObject>
- (void)popoverControllerDidClear:(PopoverController *)controller;
- (void)popoverControllerDidQuit:(PopoverController *)controller;
- (void)popoverControllerDidRequestSettings:(PopoverController *)controller;
- (void)popoverControllerDidRequestAbout:(PopoverController *)controller;
- (BOOL)popoverController:(PopoverController *)controller didChangeGoals:(NSArray<NSDictionary *> *)goals;
@end

@interface PopoverController : NSViewController
@property (nonatomic, weak) id<PopoverControllerDelegate> delegate;
- (void)setCommittedTitle:(NSString *)title
                     year:(NSInteger)year
                    month:(NSInteger)month
                      day:(NSInteger)day
               configured:(BOOL)configured;
- (void)setGoals:(NSArray<NSDictionary *> *)goals;
- (void)rerender;
- (void)showMessage:(NSString *)message;
- (void)showGoalMessage:(NSString *)message;
@end
