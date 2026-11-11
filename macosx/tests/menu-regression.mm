#import "AppDelegate.h"
#import "Cheats/S9xCheatFinderViewController.h"
#import "Cheats/S9xCheatEditViewController.h"
#import "S9xPreferences/S9xPreferencesConstants.h"
#import "S9xApplication.h"
#include "snes9x.h"
#include "ppu.h"

@interface AppDelegate (MenuRegression)
- (BOOL)validateMenuItem:(NSMenuItem *)item;
- (void)resume:(id)sender;
- (void)softwareReset:(id)sender;
- (void)hardwareReset:(id)sender;
- (void)toggleCheats:(id)sender;
- (void)toggleAudioMute:(id)sender;
- (void)performWithEmulationPaused:(dispatch_block_t)action;
- (void)openPreferencesWindow:(id)sender;
- (void)openCheatsWindow:(id)sender;
- (void)openCheatFinderWindow:(id)sender;
- (void)resetWindow;
- (BOOL)openURL:(NSURL *)url;
- (void)menuNeedsUpdate:(NSMenu *)menu;
- (void)openRecentGame:(NSMenuItem *)sender;
- (void)clearRecentGames:(id)sender;
@end

@interface S9xCheatsViewController (MenuRegression)
- (void)editSelectedCheat;
@end

@interface S9xCheatEditViewController (MenuRegression)
- (void)save:(id)sender;
@end

@interface S9xCheatFinderViewController (MenuRegression)
- (void)reload:(id)sender;
- (void)storeValues:(id)sender;
- (void)search:(id)sender;
@end

static NSUInteger checks = 0;

@interface MenuRegressionApplication : S9xApplication
@property (nonatomic, strong) NSError *lastPresentedError;
@end

@implementation MenuRegressionApplication
- (BOOL)presentError:(NSError *)error
{
    self.lastPresentedError = error;
    return YES;
}
@end

static void Check(BOOL condition, NSString *message)
{
    if (!condition)
        @throw [NSException exceptionWithName:@"RegressionFailure" reason:message userInfo:nil];
    ++checks;
}

static void Pump(NSTimeInterval duration)
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:duration];
    do
    {
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
    } while (deadline.timeIntervalSinceNow > 0);
}

static void Wait(BOOL (^condition)(void), NSString *message)
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while (!condition() && deadline.timeIntervalSinceNow > 0)
        Pump(0.005);
    Check(condition(), message);
}

static void BeginPause(S9xEngine *engine)
{
    __block BOOL ready = NO;
    [engine beginUserInterfacePause:^{ ready = YES; }];
    Wait(^BOOL { return ready; }, @"Pause acknowledged at an emulation boundary");
}

static uint32_t SampleFrames(S9xEngine *engine)
{
    BeginPause(engine);
    uint32_t frames = IPPU.TotalEmulatedFrames;
    [engine endUserInterfacePause];
    return frames;
}

static NSURL *WriteTestROM(NSURL *directory)
{
    // An original, minimal LoROM program: increment work RAM forever.
    NSMutableData *rom = [NSMutableData dataWithLength:0x8000];
    uint8_t *bytes = (uint8_t *)rom.mutableBytes;
    const uint8_t program[] = {0x78, 0x18, 0xfb, 0xc2, 0x30, 0xe6, 0x00, 0x80, 0xfc};
    memcpy(bytes, program, sizeof(program));
    memset(bytes + 0x7fc0, ' ', 21);
    memcpy(bytes + 0x7fc0, "MENU REGRESSION", 15);
    bytes[0x7fd5] = 0x20;
    bytes[0x7fd7] = 5;
    bytes[0x7fd9] = 1;
    bytes[0x7fdc] = 0xff;
    bytes[0x7fdd] = 0xff;
    bytes[0x7ffd] = 0x80;
    NSURL *url = [directory URLByAppendingPathComponent:@"menu-test.sfc"];
    NSError *error = nil;
    Check([rom writeToURL:url options:NSDataWritingAtomic error:&error], error.localizedDescription);
    return url;
}

static void TestClickAndMute(AppDelegate *delegate)
{
    S9xEngine *engine = delegate.s9xEngine;
    NSEvent *click = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown
                                      location:NSMakePoint(10, 10)
                                 modifierFlags:0 timestamp:0
                                  windowNumber:delegate.gameWindow.windowNumber
                                       context:nil eventNumber:1 clickCount:1 pressure:1];
    [s9xView mouseDown:click];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Click pause completes");
    Check(engine.isPaused, @"Clicking the game pauses");
    Pump(0.02);
    NSView *hitView = [s9xView hitTest:NSMakePoint(10, 10)];
    Check(hitView != nil, @"Paused game remains clickable");
    [hitView mouseDown:click];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Second click completes");
    Check(!engine.isPaused, @"Clicking the pause overlay resumes");

    [s9xView mouseDown:click];
    [s9xView mouseDown:click];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Rapid clicks complete");
    Check(!engine.isPaused, @"Two rapid clicks preserve the playing state");

    [engine performWithEmulationPaused:^{ [engine setDeviceSetting:Mouse]; }];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Mouse controller applies");
    [s9xView mouseDown:click];
    Check(!engine.isPaused && pressedKeys[0][kKeyMouseLeft], @"SNES mouse clicks remain game input");
    [s9xView mouseUp:click];
    [engine performWithEmulationPaused:^{ [engine setDeviceSetting:Gamepads]; }];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Gamepad controller restored");

    NSMenuItem *mute = [[NSMenuItem alloc] initWithTitle:@"Mute Audio" action:@selector(toggleAudioMute:) keyEquivalent:@""];
    Check([delegate validateMenuItem:mute] && mute.state == NSControlStateValueOff, @"Mute starts unchecked");
    uint32_t before = SampleFrames(engine);
    [delegate toggleAudioMute:nil];
    Check(engine.isAudioMuted, @"Mute menu enables output mute");
    Check([delegate validateMenuItem:mute] && mute.state == NSControlStateValueOn, @"Mute menu checkmark updates");
    Pump(0.15);
    Check(SampleFrames(engine) != before, @"Muted gameplay still advances");
    [delegate resume:nil];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Manual pause before unmute completes");
    [delegate toggleAudioMute:nil];
    Check(!engine.isAudioMuted && engine.isPaused, @"Unmute preserves a manual pause");
    [delegate resume:nil];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Resume after mute test completes");
    [delegate toggleAudioMute:nil];
}

static void TestMenus(AppDelegate *delegate)
{
    for (NSString *selector in @[@"openDocument:", @"openMultiple:", @"openPreferencesWindow:",
                                 @"softwareReset:", @"hardwareReset:", @"updateDeviceSetting:",
                                 @"openCheatsWindow:", @"openCheatFinderWindow:", @"toggleCheats:",
                                 @"terminate:"])
    {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:selector action:NSSelectorFromString(selector) keyEquivalent:@""];
        Check([delegate validateMenuItem:item], [selector stringByAppendingString:@" available while playing"]);
    }

    NSMenuItem *pauseItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(resume:) keyEquivalent:@"r"];
    Check([delegate validateMenuItem:pauseItem] && [pauseItem.title isEqualToString:@"Pause"], @"Pause command available while playing");
    [delegate resume:nil];
    Wait(^BOOL { return !delegate.s9xEngine.isPausedForUserInterface && delegate.s9xEngine.isPaused; }, @"Pause menu command pauses");
    Check([delegate validateMenuItem:pauseItem] && [pauseItem.title isEqualToString:@"Resume"], @"Paused game offers Resume");

    for (NSString *selector in @[@"softwareReset:", @"hardwareReset:"])
    {
        if ([selector isEqualToString:@"softwareReset:"])
            [delegate softwareReset:nil];
        else
            [delegate hardwareReset:nil];
        Wait(^BOOL { return !delegate.s9xEngine.isPausedForUserInterface; }, @"Reset completes");
        Check(delegate.s9xEngine.isPaused, @"Reset preserves a manual pause");
    }

    [delegate resume:nil];
    Wait(^BOOL { return !delegate.s9xEngine.isPaused; }, @"Resume menu command resumes");

    [delegate softwareReset:nil];
    Wait(^BOOL { return !delegate.s9xEngine.isPausedForUserInterface; }, @"Running reset completes");
    Check(!delegate.s9xEngine.isPaused, @"Reset while playing resumes automatically");
    BOOL cheatsEnabled = delegate.s9xEngine.cheatsEnabled;
    [delegate toggleCheats:nil];
    Wait(^BOOL { return !delegate.s9xEngine.isPausedForUserInterface; }, @"Cheat toggle completes");
    Check(delegate.s9xEngine.cheatsEnabled != cheatsEnabled && !delegate.s9xEngine.isPaused, @"Cheat toggle preserves gameplay");
    [delegate toggleCheats:nil];
    Wait(^BOOL { return !delegate.s9xEngine.isPausedForUserInterface; }, @"Cheat setting restored");
}

static void TestRecentGames(AppDelegate *delegate, NSURL *rom)
{
    [delegate clearRecentGames:nil];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Open Recent"];
    [delegate menuNeedsUpdate:menu];
    Check(menu.numberOfItems == 1 && ![delegate validateMenuItem:menu.itemArray.lastObject], @"Empty history disables Clear Menu");
    Check([delegate openURL:rom], @"Opening a ROM records history");
    Wait(^BOOL { return !delegate.s9xEngine.isPausedForUserInterface; }, @"Recent ROM window setup finishes");
    [delegate menuNeedsUpdate:menu];
    Check(menu.numberOfItems == 3 && [menu.itemArray.firstObject.representedObject isEqual:rom],
          [NSString stringWithFormat:@"Open Recent lists the loaded ROM (items=%ld, recents=%@, expected=%@)",
           (long)menu.numberOfItems, NSDocumentController.sharedDocumentController.recentDocumentURLs, rom]);
    [NSUserDefaults.standardUserDefaults synchronize];
    NSArray *savedPaths = [NSUserDefaults.standardUserDefaults persistentDomainForName:NSBundle.mainBundle.bundleIdentifier][@"RecentGamePaths"];
    Check([savedPaths containsObject:rom.path], @"Recent game history is saved in app preferences");
    AppDelegate *restoredDelegate = [AppDelegate new];
    [restoredDelegate menuNeedsUpdate:menu];
    Check([menu.itemArray.firstObject.representedObject isEqual:rom], @"A new delegate reconstructs the menu from saved history");
    NSUInteger generation = delegate.s9xEngine.romGeneration;
    [delegate openRecentGame:menu.itemArray.firstObject];
    Wait(^BOOL { return !delegate.s9xEngine.isPausedForUserInterface; }, @"Reopening a recent game finishes");
    Check(delegate.s9xEngine.romGeneration > generation, @"Recent item reloads the ROM");
    [delegate menuNeedsUpdate:menu];
    Check(menu.numberOfItems == 3, @"Opening the same ROM does not duplicate history");
    [delegate clearRecentGames:nil];
    [delegate menuNeedsUpdate:menu];
    Check(menu.numberOfItems == 1, @"Clear Menu removes recent games");
}

static void TestPauses(AppDelegate *delegate)
{
    S9xEngine *engine = delegate.s9xEngine;
    uint32_t before = SampleFrames(engine);
    Pump(0.15);
    Check(SampleFrames(engine) != before, @"Emulation advances without a UI pause");

    __block NSUInteger completions = 0;
    [engine beginUserInterfacePause:^{ ++completions; }];
    [engine beginUserInterfacePause:^{ ++completions; }];
    Wait(^BOOL { return completions == 2; }, @"Overlapping pause requests both complete");
    uint32_t pausedFrames = IPPU.TotalEmulatedFrames;
    Pump(0.1);
    Check(IPPU.TotalEmulatedFrames == pausedFrames, @"Acknowledged UI pause stops frames");
    [engine endUserInterfacePause];
    Pump(0.1);
    Check(engine.isPausedForUserInterface && IPPU.TotalEmulatedFrames == pausedFrames, @"First release does not resume an overlapping pause");
    [engine endUserInterfacePause];
    Pump(0.15);
    Check(SampleFrames(engine) != pausedFrames, @"Last release resumes gameplay");

    for (NSUInteger i = 0; i < 32; ++i)
    {
        BeginPause(engine);
        [engine endUserInterfacePause];
    }
    Check(!engine.isPausedForUserInterface, @"Back-to-back pause handoffs do not strand a request");

    __block NSMutableArray<NSNumber *> *order = [NSMutableArray new];
    for (NSUInteger i = 0; i < 16; ++i)
        [engine performWithEmulationPaused:^{ [order addObject:@(i)]; }];
    Wait(^BOOL { return order.count == 16; }, @"Rapid editor operations all finish");
    for (NSUInteger i = 0; i < 16; ++i)
        Check(order[i].unsignedIntegerValue == i, @"Rapid edits preserve request order");

    [delegate resume:nil];
    Wait(^BOOL { return !engine.isPausedForUserInterface && engine.isPaused; }, @"Manual pause established");
    BeginPause(engine);
    [engine endUserInterfacePause];
    Check(engine.isPaused, @"UI transaction preserves a manual pause");
    [delegate resume:nil];
    Wait(^BOOL { return !engine.isPaused; }, @"Manual pause cleared");

}

static void CheckLive(S9xEngine *engine, NSString *message)
{
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Pending editor operations complete");
    Check(!engine.isPaused, @"Editor does not hold a pause");
    uint32_t before = SampleFrames(engine);
    Pump(0.2);
    Check(SampleFrames(engine) != before, message);
}

static NSData *ReadRAM(S9xEngine *engine)
{
    __block NSData *ram = nil;
    [engine readRAMWithCompletion:^(NSData *snapshot) { ram = snapshot; }];
    Wait(^BOOL { return ram != nil; }, @"RAM snapshot completes");
    Check(ram.length == 0x20000, @"Snapshot contains all work RAM");
    return ram;
}

static void TestLiveEditors(AppDelegate *delegate)
{
    S9xEngine *engine = delegate.s9xEngine;
    [delegate openPreferencesWindow:nil];
    Check(delegate.preferencesWindowController.window.isVisible, @"Settings opens");
    CheckLive(engine, @"Frames advance while Settings is open");
    [delegate setShowFPS:YES];
    [delegate setVideoMode:VIDEOMODE_SMOOTH];
    [delegate setMacFrameSkip:-1];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Display changes finish");
    BeginPause(engine);
    Check(Settings.DisplayFrameRate, @"FPS preference applies during gameplay");
    [engine endUserInterfacePause];
    [NSUserDefaults.standardUserDefaults setInteger:125 forKey:kSuperFXClockSpeedPercentPref];
    [delegate applyEmulationSettings];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Emulation settings finish");
    BeginPause(engine);
    Check(Settings.SuperFXClockMultiplier == 125, @"Emulation preference applies during gameplay");
    [engine endUserInterfacePause];
    CheckLive(engine, @"Gameplay continues after applying settings");

    [delegate openCheatsWindow:nil];
    Check(delegate.cheatsWindowController.window.isVisible, @"Cheats opens");
    CheckLive(engine, @"Frames advance with Settings and Cheats both open");
    [engine performWithEmulationPaused:^
    {
        engine.cheatsEnabled = YES;
        CreateCheatFromAddress(@(0x7e0010), @(42), @"Live menu test");
    }];
    __block NSArray<S9xCheatItem *> *cheats = nil;
    [engine performWithEmulationPaused:^{ cheats = GetAllCheats(engine); }];
    Wait(^BOOL { return cheats != nil; }, @"Cheat list snapshot completes");
    Check(cheats.count == 1 && cheats[0].value.unsignedIntValue == 42, @"Cheat snapshot contains newly created cheat");
    S9xCheatItem *cheat = cheats[0];
    cheat.value = @(43);
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Live cheat edit completes");
    Pump(0.1);
    NSData *ram = ReadRAM(engine);
    Check(((const uint8_t *)ram.bytes)[0x10] == 43, @"Live cheat edit affects running game RAM");

    [delegate openCheatFinderWindow:nil];
    Check(delegate.cheatFinderWindowController.window.isVisible, @"Cheat Finder opens");
    CheckLive(engine, @"Frames advance with all three editors open");
    S9xCheatFinderViewController *finder = (S9xCheatFinderViewController *)delegate.cheatFinderWindowController.contentViewController;
    NSPopUpButton *byteSize = [finder valueForKey:@"byteSizePopUp"];
    [byteSize selectItemWithTag:1];
    [finder reload:nil];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Cheat Finder reload finishes");
    NSArray *rows = [finder valueForKey:@"addressRows"];
    Check([[rows[0x10] valueForKey:@"value"] unsignedIntValue] == 43, @"Cheat Finder reload reads fresh RAM");
    [finder storeValues:nil];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Store captures live RAM");
    cheat.value = @(44);
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Second live cheat edit finishes");
    Pump(0.1);
    NSTextField *customValue = [finder valueForKey:@"customValueField"];
    customValue.stringValue = @"44";
    [finder search:nil];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Live RAM search finishes");
    rows = [finder valueForKey:@"addressRows"];
    Check([rows indexesOfObjectsPassingTest:^BOOL(id entry, NSUInteger index, BOOL *stop)
    {
        return [[entry valueForKey:@"address"] unsignedIntValue] == 0x10 && [[entry valueForKey:@"value"] unsignedIntValue] == 44;
    }].count == 1, @"Search captures RAM changes made after opening Cheat Finder");
    CheckLive(engine, @"Search does not leave the game paused");

    S9xCheatsViewController *cheatsController = (S9xCheatsViewController *)delegate.cheatsWindowController.contentViewController;
    [cheatsController reloadData];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Cheat table refresh completes");
    NSTableView *cheatTable = [cheatsController valueForKey:@"tableView"];
    [cheatTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    [cheatsController editSelectedCheat];
    S9xCheatEditViewController *editor = (S9xCheatEditViewController *)cheatsController.presentedViewControllers.firstObject;
    Check(editor != nil, @"Cheat editing sheet opens");
    CheckLive(engine, @"Gameplay continues while editing a cheat");
    editor.valueField.objectValue = @(45);
    editor.descriptionField.stringValue = @"Edited while running";
    [editor save:nil];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Cheat editing sheet save completes");
    Pump(0.1);
    ram = ReadRAM(engine);
    Check(((const uint8_t *)ram.bytes)[0x10] == 45, @"Saving the live cheat sheet changes game RAM");

    S9xWatchPoint *watch = [S9xWatchPoint new];
    watch.address = 0x7e0010;
    watch.size = 1;
    watch.format = S9xWatchPointFormatUnsigned;
    [engine setWatchPoints:@[watch]];
    __block NSArray<S9xWatchPoint *> *watchSnapshot = nil;
    [engine readWatchPointsWithCompletion:^(NSArray<S9xWatchPoint *> *points) { watchSnapshot = points; }];
    Wait(^BOOL { return watchSnapshot != nil; }, @"Live watch update and snapshot finish");
    Check(watchSnapshot.count == 1 && watchSnapshot[0].address == watch.address, @"Live watch snapshot contains the new watch");
    [engine setWatchPoints:@[]];
    CheckLive(engine, @"Watch changes do not leave the game paused");

    cheat.enabled = @NO;
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Cheat disable finishes");
    [cheat delete];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Cheat deletion finishes");
    [delegate resume:nil];
    Wait(^BOOL { return !engine.isPausedForUserInterface && engine.isPaused; }, @"Manual pause works with editors open");
    [delegate setShowFPS:NO];
    [delegate openPreferencesWindow:nil];
    Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Settings edit while manually paused finishes");
    Check(engine.isPaused, @"Live settings preserve a manual pause");
    [delegate.preferencesWindowController close];
    [delegate.cheatsWindowController close];
    [delegate.cheatFinderWindowController close];
    Check(engine.isPaused, @"Closing live editors preserves a manual pause");
    [delegate resume:nil];
    Wait(^BOOL { return !engine.isPaused; }, @"Gameplay resumes with all editors closed");
}

int main(void)
{
    @autoreleasepool
    {
        [MenuRegressionApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        NSURL *directory = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
        NSError *error = nil;
        if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:NO attributes:nil error:&error])
        {
            fprintf(stderr, "%s\n", error.localizedDescription.UTF8String);
            return 1;
        }
        S9xEngine *engine = nil;
        int result = 0;
        @try
        {
            engine = [S9xEngine new];
            saveInROMFolder = 1;
            AppDelegate *delegate = [AppDelegate new];
            delegate.s9xEngine = engine;
            NSApp.delegate = delegate;
            NSWindow *window = [[NSWindow alloc] initWithContentRect:s9xView.frame styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
            window.releasedWhenClosed = NO;
            delegate.gameWindow = window;
            [delegate resetWindow];
            [window orderFront:nil];

            NSURL *rom = WriteTestROM(directory);
            Check([engine loadROM:rom], @"Original test ROM loads");
            Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Initial window setup completes");
            TestMenus(delegate);
            TestClickAndMute(delegate);
            TestPauses(delegate);
            TestLiveEditors(delegate);
            TestRecentGames(delegate, rom);

            BeginPause(engine);
            pthread_mutex_lock(&keyLock);
            pressedKeys[0][kRight] = true;
            pthread_mutex_unlock(&keyLock);
            [NSNotificationCenter.defaultCenter postNotificationName:NSWindowDidResignKeyNotification object:window];
            Check(!pressedKeys[0][kRight], @"Opening another window clears held keyboard input");
            [engine endUserInterfacePause];

            NSUInteger previousGeneration = engine.romGeneration;
            BeginPause(engine);
            Check([engine loadROM:rom], @"ROM replacement while UI-paused does not deadlock");
            __block BOOL reconstructed = NO;
            [delegate resetWindow];
            [engine beginUserInterfacePause:^{ reconstructed = YES; }];
            Wait(^BOOL { return reconstructed; }, @"New emulation thread acknowledges pause");
            [engine endUserInterfacePause];
            [engine endUserInterfacePause];
            Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Window rebuild releases its temporary pause");
            Check(!engine.isPaused, @"New game resumes after editor hold releases");
            Check(engine.isAudioMuted, @"Output mute survives ROM loading and display recreation");
            [delegate toggleAudioMute:nil];

            __block BOOL staleActionRan = NO;
            [engine performForROMGeneration:previousGeneration action:^{ staleActionRan = YES; }];
            Wait(^BOOL { return !engine.isPausedForUserInterface; }, @"Stale editor operation finishes");
            Check(!staleActionRan && ((MenuRegressionApplication *)NSApp).lastPresentedError.code == 1, @"Stale game edits are rejected with an explicit error");

            __block BOOL pendingAction = NO;
            [engine beginUserInterfacePause:^{ pendingAction = YES; }];
            [engine quit];
            Wait(^BOOL { return pendingAction; }, @"Shutdown completes an outstanding UI pause request");
            [engine endUserInterfacePause];
            Check(!engine.isRunning && !s9xthreadrunning && Settings.StopEmulation, @"Quit joins emulation before saving state");
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(softwareReset:) keyEquivalent:@""];
            Check(![delegate validateMenuItem:item], @"Reset disabled without a running game");
            [window orderOut:nil];
            printf("PASS: %lu menu and pause checks\n", (unsigned long)checks);
        }
        @catch (NSException *exception)
        {
            fprintf(stderr, "FAIL: %s\n", exception.reason.UTF8String);
            result = 1;
        }
        @finally
        {
            [engine quit];
            [NSUserDefaults.standardUserDefaults removePersistentDomainForName:@"com.snes9x.MenuRegressionTests"];
            if (![NSFileManager.defaultManager removeItemAtURL:directory error:&error])
            {
                fprintf(stderr, "Cleanup failed: %s\n", error.localizedDescription.UTF8String);
                result = 1;
            }
        }
        return result;
    }
}
