//
//  OMColorHelper.m
//  OMColorHelper
//
//  Created by Ole Zorn on 09/07/12.
//
//

#import "OMColorHelper.h"
#import "OMPlainColorWell.h"
#import "OMColorFrameView.h"

// from XVim2
// https://github.com/XVimProject/XVim2
#import "_TtC15IDESourceEditor19IDESourceEditorView.h"

#define kOMColorHelperHighlightingDisabled	@"OMColorHelperHighlightingDisabled"
#define kOMColorHelperInsertionMode			@"OMColorHelperInsertionMode"

@implementation OMColorHelper

@synthesize colorWell=_colorWell, colorFrameView=_colorFrameView, textView=_textView, selectedColorRange=_selectedColorRange, selectedColorType=_selectedColorType;

#pragma mark - Plugin Initialization

+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static id sharedPlugin = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedPlugin = [[self alloc] init];
	});
}

- (id)init
{
	if (self = [super init]) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];
		_selectedColorRange = NSMakeRange(NSNotFound, 0);
		_constantColorsByName = [[NSDictionary alloc] initWithObjectsAndKeys:
								 [[NSColor blackColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]], @"black",
								 [NSColor darkGrayColor], @"darkGray",
								 [NSColor lightGrayColor], @"lightGray",
								 [[NSColor whiteColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]], @"white",
								 [NSColor grayColor], @"gray",
								 [NSColor redColor], @"red",
								 [NSColor greenColor], @"green",
								 [NSColor blueColor], @"blue",
								 [NSColor cyanColor], @"cyan",
								 [NSColor yellowColor], @"yellow",
								 [NSColor magentaColor], @"magenta",
								 [NSColor orangeColor], @"orange",
								 [NSColor purpleColor], @"purple",
								 [NSColor brownColor], @"brown",
								 [[NSColor clearColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]], @"clear", nil];
		
		_rgbaUIColorRegex = [NSRegularExpression regularExpressionWithPattern:@"(\\[\\s*UIColor\\s+colorWith|\\[\\s*\\[\\s*UIColor\\s+alloc\\]\\s*initWith)Red:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s+green:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s+blue:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s*alpha:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s*\\]" options:0 error:NULL];
		_whiteUIColorRegex = [NSRegularExpression regularExpressionWithPattern:@"(\\[\\s*UIColor\\s+colorWith|\\[\\s*\\[\\s*UIColor\\s+alloc\\]\\s*initWith)White:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s+alpha:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s*\\]" options:0 error:NULL];
		_rgbaNSColorRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[\\s*NSColor\\s+colorWith(Calibrated|Device)Red:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s+green:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s+blue:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s+alpha:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s*\\]" options:0 error:NULL];
		_whiteNSColorRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[\\s*NSColor\\s+colorWith(Calibrated|Device)White:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s+alpha:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s*\\]" options:0 error:NULL];
		_constantColorRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[\\s*(UI|NS)Color\\s+(black|darkGray|lightGray|white|gray|red|green|blue|cyan|yellow|magenta|orange|purple|brown|clear)Color\\s*\\]" options:0 error:NULL];
        _hexUIColorRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[\\s*UIColor\\s+(colorWithHex:\\s*(0[xX][0-9a-fA-F]{1,6})(\\s+alpha:\\s*([0-9]*.?[0-9]{1,})f?)?)\\s*\\]" options:0 error:NULL];
	}
	return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
	if (editMenuItem) {
		[[editMenuItem submenu] addItem:[NSMenuItem separatorItem]];
		
		NSMenuItem *toggleColorHighlightingMenuItem = [[NSMenuItem alloc] initWithTitle:@"Show Colors Under Caret" action:@selector(toggleColorHighlightingEnabled:) keyEquivalent:@""];
		[toggleColorHighlightingMenuItem setTarget:self];
		[[editMenuItem submenu] addItem:toggleColorHighlightingMenuItem];
		
		NSMenuItem *colorInsertionModeItem = [[NSMenuItem alloc] initWithTitle:@"Color Insertion Mode" action:nil keyEquivalent:@""];
		NSMenuItem *colorInsertionModeNSItem = [[NSMenuItem alloc] initWithTitle:@"NSColor" action:@selector(selectNSColorInsertionMode:) keyEquivalent:@""];
		[colorInsertionModeNSItem setTarget:self];
		NSMenuItem *colorInsertionModeUIItem = [[NSMenuItem alloc] initWithTitle:@"UIColor" action:@selector(selectUIColorInsertionMode:) keyEquivalent:@""];
		[colorInsertionModeUIItem setTarget:self];
		
		NSMenu *colorInsertionModeMenu = [[NSMenu alloc] initWithTitle:@"Color Insertion Mode"];
		[colorInsertionModeItem setSubmenu:colorInsertionModeMenu];
		[[colorInsertionModeItem submenu] addItem:colorInsertionModeUIItem];
		[[colorInsertionModeItem submenu] addItem:colorInsertionModeNSItem];
		[[editMenuItem submenu] addItem:colorInsertionModeItem];
		
		NSMenuItem *insertColorMenuItem = [[NSMenuItem alloc] initWithTitle:@"Insert Color..." action:@selector(insertColor:) keyEquivalent:@""];
		[insertColorMenuItem setTarget:self];
		[[editMenuItem submenu] addItem:insertColorMenuItem];
	}
	
	BOOL highlightingEnabled = ![[NSUserDefaults standardUserDefaults] boolForKey:kOMColorHelperHighlightingDisabled];
	if (highlightingEnabled) {
		[self activateColorHighlighting];
	}
    
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(check:) name:nil object:nil];
}

// for test
- (void)check:(NSNotification *)notification
{
    //NSTextDidChangeNotification
    //SourceEditorSelectedSourceRangeChangedNotification
    
    NSRange rang = [notification.name rangeOfString:@"Notification"];
    
    if (rang.length)
    {

        if ([notification.name isEqualToString:@"NSWindowDidResignKeyNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSWindowDidMoveNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSApplicationWillResignActiveNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSApplicationDidResignActiveNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSWindowDidBecomeKeyNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSWindowDidEndDraggingNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"IDEWorkspaceDocumentWillWriteStateDataNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSMenuDidRemoveItemNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSMenuDidRemoveAllItemsNotification"])
        {
            return;
        }

        
        if ([notification.name isEqualToString:@"DVTDeveloperAccountsChangedNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"IDENavigableItemCoordinatorArrangedObjectGraphChangeNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSOutlineViewSelectionDidChangeNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"DVTWeakInterposerRepresentedObjectIsDeallocatingNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"IDEIndexDidChangeStateNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"IDEIndexDidChangeNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"IDEBuildSchemeActionBuildablesDidChangeNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"IDESchemeActionRunnableDidChangeNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSBundleDidLoadNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"_NSThreadDidStartNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSThreadWillExitNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"IDENavigableItemCoordinatorObjectGraphChangeNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"IDEControlGroupDidChangeNotificationName"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSSplitViewWillResizeSubviewsNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSSplitViewDidResizeSubviewsNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"IDENavigableItemCoordinatorWillForgetItemsNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"IDENavigableItemCoordinatorDidForgetItemsNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSFileHandleDataAvailableNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSMenuDidChangeItemNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSMenuDidAddItemNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSOutlineViewItemWillExpandNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSOutlineViewItemDidExpandNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSApplicationWillUpdateNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSApplicationDidUpdateNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"DVTModelObjectGraphDidCoalesceChangesNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"IDENavigableItemCoordinatorPropertyValuesChangeNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"DVTModelObjectGraphWillCoalesceChangesNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSViewDidUpdateTrackingAreasNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSWindowDidUpdateNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"IDEIndexIsIndexingWorkspaceNotification"])
        {
            return;
        }

        if ([notification.name isEqualToString:@"NSUserDefaultsDidChangeNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSTextInputContextKeyboardSelectionDidChangeNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"NSViewFrameDidChangeNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"DVTModelObjectGraphObjectsDidChangeNotificationName"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"DVTDeviceUsabilityDidChangeNotification"])
        {
            return;
        }
        if ([notification.name isEqualToString:@"DVTSourceExpressionUnderMouseDidChangeNotification"])
        {
            return;
        }
        NSLog(@"notification: %@", notification.name);
    }
}

#pragma mark - Preferences

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(insertColor:)) {
		NSResponder *firstResponder = [[NSApp keyWindow] firstResponder];
        return ([firstResponder isKindOfClass:NSClassFromString(@"IDESourceEditor.IDESourceEditorView")]);
	} else if ([menuItem action] == @selector(toggleColorHighlightingEnabled:)) {
		BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMColorHelperHighlightingDisabled];
		[menuItem setState:enabled ? NSOffState : NSOnState];
		return YES;
	} else if ([menuItem action] == @selector(selectNSColorInsertionMode:)) {
		[menuItem setState:[[NSUserDefaults standardUserDefaults] integerForKey:kOMColorHelperInsertionMode] == 1 ? NSOnState : NSOffState];
	} else if ([menuItem action] == @selector(selectUIColorInsertionMode:)) {
		[menuItem setState:[[NSUserDefaults standardUserDefaults] integerForKey:kOMColorHelperInsertionMode] == 0 ? NSOnState : NSOffState];
	}
	return YES;
}

- (void)selectNSColorInsertionMode:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:1 forKey:kOMColorHelperInsertionMode];
}

- (void)selectUIColorInsertionMode:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kOMColorHelperInsertionMode];
}

- (void)toggleColorHighlightingEnabled:(id)sender
{
	BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMColorHelperHighlightingDisabled];
	[[NSUserDefaults standardUserDefaults] setBool:!enabled forKey:kOMColorHelperHighlightingDisabled];
	if (enabled) {
		[self activateColorHighlighting];
	} else {
		[self deactivateColorHighlighting];
	}
}

- (void)activateColorHighlighting
{
    if (!self.textView) {
        NSResponder *firstResponder = [[NSApp keyWindow] firstResponder];
        if ([firstResponder isKindOfClass:NSClassFromString(@"IDESourceEditor.IDESourceEditorView")]) {
                self.textView = (_TtC15IDESourceEditor19IDESourceEditorView *)firstResponder;
        }
    }
    
    if (self.textView)
    {
        NSNotification *notification = [NSNotification notificationWithName:NSTextDidChangeNotification object:self.textView];
        [self selectionDidChange:notification];
    }
    else
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectionDidChange:) name:nil object:nil];
    }
}

- (void)deactivateColorHighlighting
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSTextViewDidChangeSelectionNotification object:nil];
	[self dismissColorWell];
	//self.textView = nil;
}

#pragma mark - Color Insertion

- (void)insertColor:(id)sender
{
	if (!self.textView) {
		NSResponder *firstResponder = [[NSApp keyWindow] firstResponder];
        if ([firstResponder isKindOfClass:NSClassFromString(@"IDESourceEditor.IDESourceEditorView")]) {
            self.textView = (_TtC15IDESourceEditor19IDESourceEditorView *)firstResponder;
		} else {
			NSBeep();
			return;
		}
	}
	if ([[NSUserDefaults standardUserDefaults] boolForKey:kOMColorHelperHighlightingDisabled]) {
		//Inserting a color implicitly activates color highlighting:
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kOMColorHelperHighlightingDisabled];
		[self activateColorHighlighting];
	}
	[self.textView.undoManager beginUndoGrouping];
	NSInteger insertionMode = [[NSUserDefaults standardUserDefaults] integerForKey:kOMColorHelperInsertionMode];
	if (insertionMode == 0) {
		[self.textView insertText:@"[UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:1.0]" replacementRange:self.textView.selectedRange];
	} else {
		[self.textView insertText:@"[NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:1.0]" replacementRange:self.textView.selectedRange];
	}
	[self.textView.undoManager endUndoGrouping];
	[self performSelector:@selector(activateColorWell) withObject:nil afterDelay:0.0];
}

- (void)activateColorWell
{
	[self.colorWell activate:YES];
}

#pragma mark - Text Selection Handling

- (void)selectionDidChange:(NSNotification *)notification
{
    // NSScrollViewWillStartLiveScrollNotification
    // 滚动事件
    if ([notification.name isEqualToString:@"NSScrollViewWillStartLiveScrollNotification"])
    {
        [self dismissColorWell];
        return;
    }

    // SourceEditorSelectedSourceRangeChangedNotification
    // 光标移动
    if (![notification.name isEqualToString:@"SourceEditorSelectedSourceRangeChangedNotification"])
    {
        return;
    }
    
    NSView *view = [notification object];
    NSString *clasName = view.className;
    
    if ([clasName isEqualToString:@"IDESourceEditor.IDESourceEditorView"])
    {
        for (NSView *sview in view.subviews)
        {
            NSString *clasName1 = sview.className;
            NSLog(@"%@", clasName1);
        }

        self.textView = (_TtC15IDESourceEditor19IDESourceEditorView *)[notification object];
		
		BOOL disabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMColorHelperHighlightingDisabled];
		if (disabled) return;
		
        NSRange selectedRange = [self.textView selectedRange]; //[[selectedRanges objectAtIndex:0] rangeValue];
        NSString *text = self.textView.string;//self.textView.textStorage.string;
            NSRange lineRange = [text lineRangeForRange:selectedRange];
            NSRange selectedRangeInLine = NSMakeRange(selectedRange.location - lineRange.location, selectedRange.length);
            NSString *line = [text substringWithRange:lineRange];
        
        if (line.length < 10)
        {
            [self dismissColorFrameView];
            return;
        }
        
        NSRange colorRange = NSMakeRange(NSNotFound, 0);
        OMColorType colorType = OMColorTypeNone;
        NSColor *matchedColor = [self colorInText:line selectedRange:selectedRangeInLine type:&colorType matchedRange:&colorRange];
        
        if (matchedColor) {
            NSColor *bgColor = [NSColor colorWithCGColor:self.textView.layer.backgroundColor];
            NSColor *backgroundColor = [bgColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
            CGFloat r = 1.0; CGFloat g = 1.0; CGFloat b = 1.0;
            [backgroundColor getRed:&r green:&g blue:&b alpha:NULL];
            CGFloat backgroundLuminance = (r + g + b) / 3.0;
            
            NSColor *strokeColor = (backgroundLuminance > 0.5) ? [NSColor colorWithCalibratedWhite:0.2 alpha:1.0] : [NSColor whiteColor];
            
            self.selectedColorType = colorType;
            self.colorWell.color = matchedColor;
            self.colorWell.strokeColor = strokeColor;
            
            self.selectedColorRange = NSMakeRange(colorRange.location + lineRange.location, colorRange.length);
            NSRect selectionRectOnScreen = [self.textView firstRectForCharacterRange:self.selectedColorRange actualRange:nil]; //[self.textView firstRectForCharacterRange:self.selectedColorRange];
            NSRect selectionRectInWindow = [self.textView.window convertRectFromScreen:selectionRectOnScreen];
            NSRect selectionRectInView = [self.textView convertRect:selectionRectInWindow fromView:nil];
            NSRect colorWellRect = NSMakeRect(NSMaxX(selectionRectInView) - 49, NSMinY(selectionRectInView) - selectionRectInView.size.height - 2, 50, selectionRectInView.size.height + 2);
            self.colorWell.frame = NSIntegralRect(colorWellRect);
            [self.textView addSubview:self.colorWell];
            self.colorFrameView.frame = NSInsetRect(NSIntegralRect(selectionRectInView), -1, -1);
            
            self.colorFrameView.color = strokeColor;
            
            [self.textView addSubview:self.colorFrameView];
        } else {
            [self dismissColorWell];
        }
	}
}

/*
NSArray *selectedRanges = [self.textView selectedRanges];
if (selectedRanges.count >= 1) {
    NSRange selectedRange = [[selectedRanges objectAtIndex:0] rangeValue];
    NSString *text = self.textView.textStorage.string;
    NSRange lineRange = [text lineRangeForRange:selectedRange];
    NSRange selectedRangeInLine = NSMakeRange(selectedRange.location - lineRange.location, selectedRange.length);
    NSString *line = [text substringWithRange:lineRange];
    
    NSRange colorRange = NSMakeRange(NSNotFound, 0);
    OMColorType colorType = OMColorTypeNone;
    NSColor *matchedColor = [self colorInText:line selectedRange:selectedRangeInLine type:&colorType matchedRange:&colorRange];
    
    if (matchedColor) {
        NSColor *backgroundColor = [self.textView.backgroundColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
        CGFloat r = 1.0; CGFloat g = 1.0; CGFloat b = 1.0;
        [backgroundColor getRed:&r green:&g blue:&b alpha:NULL];
        CGFloat backgroundLuminance = (r + g + b) / 3.0;
        
        NSColor *strokeColor = (backgroundLuminance > 0.5) ? [NSColor colorWithCalibratedWhite:0.2 alpha:1.0] : [NSColor whiteColor];
        
        self.selectedColorType = colorType;
        self.colorWell.color = matchedColor;
        self.colorWell.strokeColor = strokeColor;
        
        self.selectedColorRange = NSMakeRange(colorRange.location + lineRange.location, colorRange.length);
        NSRect selectionRectOnScreen = [self.textView firstRectForCharacterRange:self.selectedColorRange];
        NSRect selectionRectInWindow = [self.textView.window convertRectFromScreen:selectionRectOnScreen];
        NSRect selectionRectInView = [self.textView convertRect:selectionRectInWindow fromView:nil];
        NSRect colorWellRect = NSMakeRect(NSMaxX(selectionRectInView) - 49, NSMinY(selectionRectInView) - selectionRectInView.size.height - 2, 50, selectionRectInView.size.height + 2);
        self.colorWell.frame = NSIntegralRect(colorWellRect);
        [self.textView addSubview:self.colorWell];
        self.colorFrameView.frame = NSInsetRect(NSIntegralRect(selectionRectInView), -1, -1);
        
        self.colorFrameView.color = strokeColor;
        
        [self.textView addSubview:self.colorFrameView];
    } else {
        [self dismissColorWell];
    }
} else {
    [self dismissColorWell];
}
*/

- (void)dismissColorFrameView
{
    [self.colorFrameView removeFromSuperview];
    self.selectedColorRange = NSMakeRange(NSNotFound, 0);
    self.selectedColorType = OMColorTypeNone;
}

- (void)dismissColorWell
{
	if (self.colorWell.isActive) {
		[self.colorWell deactivate];
		[[NSColorPanel sharedColorPanel] orderOut:nil];
	}
	[self.colorWell removeFromSuperview];
    
    [self dismissColorFrameView];
}

- (void)colorDidChange:(id)sender
{
	if (self.selectedColorRange.location == NSNotFound) {
		return;
	}
	NSString *colorString = [self colorStringForColor:self.colorWell.color withType:self.selectedColorType];
	if (colorString) {
		[self.textView.undoManager beginUndoGrouping];
		[self.textView insertText:colorString replacementRange:self.selectedColorRange];
		[self.textView.undoManager endUndoGrouping];
	}
}

#pragma mark - View Initialization

- (OMPlainColorWell *)colorWell
{
	if (!_colorWell) {
		_colorWell = [[OMPlainColorWell alloc] initWithFrame:NSMakeRect(0, 0, 50, 30)];
		[_colorWell setTarget:self];
		[_colorWell setAction:@selector(colorDidChange:)];
	}
	return _colorWell;
}

- (OMColorFrameView *)colorFrameView
{
	if (!_colorFrameView) {
		_colorFrameView = [[OMColorFrameView alloc] initWithFrame:NSZeroRect];
	}
	return _colorFrameView;
}

#pragma mark - Color String Parsing

- (NSColor *)colorInText:(NSString *)text selectedRange:(NSRange)selectedRange type:(OMColorType *)type matchedRange:(NSRangePointer)matchedRange
{
	__block NSColor *foundColor = nil;
	__block NSRange foundColorRange = NSMakeRange(NSNotFound, 0);
	__block OMColorType foundColorType = OMColorTypeNone;
	
	[_rgbaUIColorRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
		NSRange colorRange = [result range];
		if (selectedRange.location >= colorRange.location && NSMaxRange(selectedRange) <= NSMaxRange(colorRange)) {
			NSString *typeIndicator = [text substringWithRange:[result rangeAtIndex:1]];
			if ([typeIndicator rangeOfString:@"init"].location != NSNotFound) {
				foundColorType = OMColorTypeUIRGBAInit;
			} else {
				foundColorType = OMColorTypeUIRGBA;
			}
			
			// [UIColor colorWithRed:128 / 255.0 green:10 / 255 blue:123/255 alpha:128 /255]
			
			double red = [[text substringWithRange:[result rangeAtIndex:2]] doubleValue];
			red = [self dividedValue:red withDivisorRange:[result rangeAtIndex:3] inString:text];
			
			double green = [[text substringWithRange:[result rangeAtIndex:4]] doubleValue];
			green = [self dividedValue:green withDivisorRange:[result rangeAtIndex:5] inString:text];
			
			double blue = [[text substringWithRange:[result rangeAtIndex:6]] doubleValue];
			blue = [self dividedValue:blue withDivisorRange:[result rangeAtIndex:7] inString:text];
			
			double alpha = [[text substringWithRange:[result rangeAtIndex:8]] doubleValue];
			alpha = [self dividedValue:alpha withDivisorRange:[result rangeAtIndex:9] inString:text];
			
			foundColor = [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
			foundColorRange = colorRange;
			*stop = YES;
		}
	}];
	
    if (!foundColor) {
        [_hexUIColorRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            NSRange colorRange = [result range];
            if (selectedRange.location >= colorRange.location && NSMaxRange(selectedRange) <= NSMaxRange(colorRange)) {
                NSString *typeIndicator = [text substringWithRange:[result rangeAtIndex:1]];
                
                if ([typeIndicator rangeOfString:@"alpha:"].location != NSNotFound) {
                    foundColorType = OMColorTypeUIHexAlpha;
                } else {
                    foundColorType = OMColorTypeUIHex;
                }
                
                NSString *hex = [text substringWithRange:[result rangeAtIndex:2]];
                double alpha = 1.0;
                if (foundColorType == OMColorTypeUIHexAlpha)
                {
                    alpha = [[text substringWithRange:[result rangeAtIndex:4]] doubleValue];
                }
                
                foundColor = [self colorWithHexString:hex alpha:alpha];
                foundColorRange = colorRange;
                *stop = YES;
            }
        }];
    }
    
	if (!foundColor) {
		[_whiteUIColorRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
			NSRange colorRange = [result range];
			if (selectedRange.location >= colorRange.location && NSMaxRange(selectedRange) <= NSMaxRange(colorRange)) {
				NSString *typeIndicator = [text substringWithRange:[result rangeAtIndex:1]];
				if ([typeIndicator rangeOfString:@"init"].location != NSNotFound) {
					foundColorType = OMColorTypeUIWhiteInit;
				} else {
					foundColorType = OMColorTypeUIWhite;
				}
				double white = [[text substringWithRange:[result rangeAtIndex:2]] doubleValue];
				white = [self dividedValue:white withDivisorRange:[result rangeAtIndex:3] inString:text];
				
				double alpha = [[text substringWithRange:[result rangeAtIndex:4]] doubleValue];
				alpha = [self dividedValue:alpha withDivisorRange:[result rangeAtIndex:5] inString:text];
				
				foundColor = [NSColor colorWithCalibratedWhite:white alpha:alpha];
				foundColorRange = colorRange;
				*stop = YES;
			}
		}];
	}
	
	if (!foundColor) {
		[_constantColorRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
			NSRange colorRange = [result range];
			if (selectedRange.location >= colorRange.location && NSMaxRange(selectedRange) <= NSMaxRange(colorRange)) {
				NSString *NS_UI = [text substringWithRange:[result rangeAtIndex:1]];
				NSString *colorName = [text substringWithRange:[result rangeAtIndex:2]];
				foundColor = [_constantColorsByName objectForKey:colorName];
				foundColorRange = colorRange;
				if ([NS_UI isEqualToString:@"UI"]) {
					foundColorType = OMColorTypeUIConstant;
				} else {
					foundColorType = OMColorTypeNSConstant;
				}
				*stop = YES;
			}
		}];
	}
	
	if (!foundColor) {
		[_rgbaNSColorRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
			NSRange colorRange = [result range];
			if (selectedRange.location >= colorRange.location && NSMaxRange(selectedRange) <= NSMaxRange(colorRange)) {
				NSString *deviceOrCalibrated = [text substringWithRange:[result rangeAtIndex:1]];
				if ([deviceOrCalibrated isEqualToString:@"Device"]) {
					foundColorType = OMColorTypeNSRGBADevice;
				} else {
					foundColorType = OMColorTypeNSRGBACalibrated;
				}
				double red = [[text substringWithRange:[result rangeAtIndex:2]] doubleValue];
				red = [self dividedValue:red withDivisorRange:[result rangeAtIndex:3] inString:text];
				
				double green = [[text substringWithRange:[result rangeAtIndex:4]] doubleValue];
				green = [self dividedValue:green withDivisorRange:[result rangeAtIndex:5] inString:text];
				
				double blue = [[text substringWithRange:[result rangeAtIndex:6]] doubleValue];
				blue = [self dividedValue:blue withDivisorRange:[result rangeAtIndex:7] inString:text];
				
				double alpha = [[text substringWithRange:[result rangeAtIndex:8]] doubleValue];
				alpha = [self dividedValue:alpha withDivisorRange:[result rangeAtIndex:9] inString:text];
				
				if (foundColorType == OMColorTypeNSRGBACalibrated) {
					foundColor = [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
				} else {
					foundColor = [NSColor colorWithDeviceRed:red green:green blue:blue alpha:alpha];
				}
				foundColorRange = colorRange;
				*stop = YES;
			}
		}];
	}
	
	if (!foundColor) {
		[_whiteNSColorRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
			NSRange colorRange = [result range];
			if (selectedRange.location >= colorRange.location && NSMaxRange(selectedRange) <= NSMaxRange(colorRange)) {
				NSString *deviceOrCalibrated = [text substringWithRange:[result rangeAtIndex:1]];
				double white = [[text substringWithRange:[result rangeAtIndex:2]] doubleValue];
				white = [self dividedValue:white withDivisorRange:[result rangeAtIndex:3] inString:text];
				
				double alpha = [[text substringWithRange:[result rangeAtIndex:4]] doubleValue];
				alpha = [self dividedValue:alpha withDivisorRange:[result rangeAtIndex:5] inString:text];
				
				if ([deviceOrCalibrated isEqualToString:@"Device"]) {
					foundColor = [NSColor colorWithDeviceWhite:white alpha:alpha];
					foundColorType = OMColorTypeNSWhiteDevice;
				} else {
					foundColor = [NSColor colorWithCalibratedWhite:white alpha:alpha];
					foundColorType = OMColorTypeNSWhiteCalibrated;
				}
				foundColorRange = colorRange;
				*stop = YES;
			}
		}];
	}
	
	if (foundColor) {
		if (matchedRange != NULL) {
			*matchedRange = foundColorRange;
		}
		if (type != NULL) {
			*type = foundColorType;
		}
		return foundColor;
	}
	
	return nil;
}

- (double)dividedValue:(double)value withDivisorRange:(NSRange)divisorRange inString:(NSString *)text
{
	if (divisorRange.location != NSNotFound) {
		double divisor = [[[text substringWithRange:divisorRange] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/ "]] doubleValue];
		if (divisor != 0) {
			value /= divisor;
		}
	}
	return value;
}

- (NSString *)colorStringForColor:(NSColor *)color withType:(OMColorType)colorType
{
	NSString *colorString = nil;
	CGFloat red = -1.0; CGFloat green = -1.0; CGFloat blue = -1.0; CGFloat alpha = -1.0;
	color = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
	[color getRed:&red green:&green blue:&blue alpha:&alpha];
		
	if (red >= 0) {
		for (NSString *colorName in _constantColorsByName) {
			NSColor *constantColor = [_constantColorsByName objectForKey:colorName];
			if ([constantColor isEqual:color]) {
				if (OMColorTypeIsNSColor(colorType)) {
					colorString = [NSString stringWithFormat:@"[NSColor %@Color]", colorName];
				} else {
					colorString = [NSString stringWithFormat:@"[UIColor %@Color]", colorName];
				}
				break;
			}
		}
		if (!colorString) {
            if (colorType == OMColorTypeUIHex || colorType == OMColorTypeUIHexAlpha)
            {
                colorString = [NSString stringWithFormat:@"[UIColor colorWithHex:0x%lX%lX%lX alpha:%.3f]", (NSInteger)(red*255), (NSInteger)(green*255), (NSInteger)(blue*255), alpha];
            }
            else
            {
                if (fabs(red - green) < 0.001 && fabs(green - blue) < 0.001) {
                    if (colorType == OMColorTypeUIRGBA || colorType == OMColorTypeUIWhite || colorType == OMColorTypeUIConstant) {
                        colorString = [NSString stringWithFormat:@"[UIColor colorWithWhite:%.3f alpha:%.3f]", red, alpha];
                    } else if (colorType == OMColorTypeUIRGBAInit || colorType == OMColorTypeUIWhiteInit) {
                        colorString = [NSString stringWithFormat:@"[[UIColor alloc] initWithWhite:%.3f alpha:%.3f]", red, alpha];
                    }
                    else if (colorType == OMColorTypeNSConstant || colorType == OMColorTypeNSRGBACalibrated || colorType == OMColorTypeNSWhiteCalibrated) {
                        colorString = [NSString stringWithFormat:@"[NSColor colorWithCalibratedWhite:%.3f alpha:%.3f]", red, alpha];
                    } else if (colorType == OMColorTypeNSRGBADevice || colorType == OMColorTypeNSWhiteDevice) {
                        colorString = [NSString stringWithFormat:@"[NSColor colorWithDeviceWhite:%.3f alpha:%.3f]", red, alpha];
                    }
                } else {
                    if (colorType == OMColorTypeUIRGBA || colorType == OMColorTypeUIWhite || colorType == OMColorTypeUIConstant) {
                        colorString = [NSString stringWithFormat:@"[UIColor colorWithRed:%.3f green:%.3f blue:%.3f alpha:%.3f]", red, green, blue, alpha];
                    } else if (colorType == OMColorTypeUIRGBAInit || colorType == OMColorTypeUIWhiteInit) {
                        colorString = [NSString stringWithFormat:@"[[UIColor alloc] initWithRed:%.3f green:%.3f blue:%.3f alpha:%.3f]", red, green, blue, alpha];
                    }
                    else if (colorType == OMColorTypeNSConstant || colorType == OMColorTypeNSRGBACalibrated || colorType == OMColorTypeNSWhiteCalibrated) {
                        colorString = [NSString stringWithFormat:@"[NSColor colorWithCalibratedRed:%.3f green:%.3f blue:%.3f alpha:%.3f]", red, green, blue, alpha];
                    } else if (colorType == OMColorTypeNSRGBADevice || colorType == OMColorTypeNSWhiteDevice) {
                        colorString = [NSString stringWithFormat:@"[NSColor colorWithDeviceRed:%.3f green:%.3f blue:%.3f alpha:%.3f]", red, green, blue, alpha];
                    }
                }
            }
		}
	}
	return colorString;
}

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSColor *)colorWithHexString:(NSString *)stringToConvert alpha:(CGFloat)alpha
{
    NSString *cString = [[stringToConvert stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    
    // String should be 6 or 8 characters
    if ([cString length] < 3)
        return [NSColor whiteColor];
    
    // strip 0X if it appears
    if ([cString hasPrefix:@"0X"] || [cString hasPrefix:@"0x"])
    {
        cString = [cString substringFromIndex:2];
    }
    else if ([cString hasPrefix:@"＃"] || [cString hasPrefix:@"#"])
    {
        cString = [cString substringFromIndex:1];
    }
    
    NSInteger length = cString.length;
    if (length != 2 && length != 4 && length != 6)
        return [NSColor whiteColor];
    
    // Separate into r, g, b substrings
    unsigned int r = 0, g = 0, b = 0;

    NSRange range;
    range.location = 0;
    range.length = 2;
    NSString *rString = [cString substringWithRange:range];
    [[NSScanner scannerWithString:rString] scanHexInt:&r];
    
    range.location = 2;
    NSString *gString = nil;
    if (length > 2)
    {
        gString = [cString substringWithRange:range];
        [[NSScanner scannerWithString:gString] scanHexInt:&g];
    }
    
    range.location = 4;
    NSString *bString = nil;
    if (length > 4)
    {
        bString = [cString substringWithRange:range];
        [[NSScanner scannerWithString:bString] scanHexInt:&b];
    }
    
    // Scan values
    return [NSColor colorWithRed:((float) r / 255.0f)
                               green:((float) g / 255.0f)
                                blue:((float) b / 255.0f)
                               alpha:alpha];
}

@end
