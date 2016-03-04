//
//  LGTemplateRenderPanel.m
//  AutoPkgr
//
//  Created by Eldon on 12/6/15.
//  Copyright © 2015-2016 The Linde Group, Inc. All rights reserved.
//

#import "LGTemplateRenderWindowController.h"
#import "LGNotificationService.h"
#import "LGNotificationManager.h"

#import <GRMustache/GRMustache.h>
#import <ACEView/ACEView.h>
#import <ACEView/ACEThemeNames.h>
#import <ACEView/ACEModeNames.h>

#import <MMMarkdown/MMMarkdown.h>

@interface LGTemplateRenderWindowController ()< NSWindowDelegate, WebResourceLoadDelegate, ACEViewDelegate, NSOutlineViewDataSource>

@property (unsafe_unretained) IBOutlet ACEView *inputView;
@property (unsafe_unretained) IBOutlet NSPopUpButton *themeMenu;

@property (unsafe_unretained) IBOutlet NSPopUpButton *serviceClassMenu;

@property (weak) IBOutlet WebView *renderView;
@property (unsafe_unretained) IBOutlet NSTextField *errorReport;

@property (weak) IBOutlet NSOutlineView *exampleDataOutlineView;
@property (weak) IBOutlet NSButton *unsavedChanges;

@end

@implementation LGTemplateRenderWindowController {
    Class _serviceClass;
    GRMustacheTemplate *_template;
    NSString *_templateString;
    ACEMode _currentMode;
    BOOL _textDidChangeDidDefer;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    // Implement this method to handle any initialization after your
    // window controller's window has been loaded from its nib file.
    //
}

- (void)awakeFromNib {
    self.inputView.delegate = self;
    self.unsavedChanges.enabled = NO;

    ACETheme theme = [[NSUserDefaults standardUserDefaults] integerForKey:@"SyntaxEditorTheme"];
    [self.inputView setTheme:theme];

    [self.themeMenu addItemsWithTitles:[ACEThemeNames humanThemeNames]];
    [self.themeMenu setTarget:self];
    [self.themeMenu setAction:@selector(themeChanged:)];
    [self.themeMenu selectItemAtIndex:theme];

    [self.serviceClassMenu addItemsWithTitles:[self serviceTitles]];
    [self.serviceClassMenu setTarget:self];
    [self.serviceClassMenu setAction:@selector(serviceClassChanged:)];

    [self serviceClassChanged:self.serviceClassMenu];
    [self.exampleDataOutlineView reloadData];
}

- (void)setServiceClass:(Class)serviceClass {
    _serviceClass = serviceClass;
    _currentMode = _serviceClass ?
        [_serviceClass tempateFormat] : ACEModeHTML;
}

- (NSString *)templateString {
    return self.inputView.string;
}

- (NSArray *)serviceTitles {
    return [NotificationServiceClasses() mapObjectsUsingBlock:^id(Class c, NSUInteger idx) {
        return [c serviceDescription];
    }];
}

- (NSDictionary *)exampleData {
    if (!_exampleData) {
        NSString *dataFile = [[NSBundle mainBundle] pathForResource:@"example_data" ofType:@"plist"];
        _exampleData = [NSDictionary dictionaryWithContentsOfFile:dataFile];
    }
    return _exampleData;
}

- (IBAction)resetToDefault:(id)sender {
    if ([_serviceClass isSubclassOfClass:[LGNotificationService class]]) {
        _inputView.string = [_serviceClass defaultTemplate];
    }
}

- (IBAction)sendExampleNotification:(NSButton *)sender {
    if ([_serviceClass isSubclassOfClass:[LGNotificationService class]]) {
        id<LGNotificationServiceProtocol> noteService =[[_serviceClass alloc] init];

        NSString *origTitle = [sender title];

        sender.title = @"Sending";
        sender.enabled = NO;
        [noteService sendMessage:[self renderedText:nil] title:@"AutoPkgr Template Example" complete:^(NSError *e){
            sender.enabled = YES;
            sender.title = origTitle;
        }];
    }
}

- (IBAction)save:(id)sender {
    if ([self renderToView:_inputView.string]) {
        self.unsavedChanges.enabled = NO;
        [_serviceClass setReportTemplate:_inputView.string];
    } else {
        NSInteger line = [self errorLine];
        if (line) {
            [_inputView gotoLine:line column:0 animated:YES];
        }
    }
}

- (IBAction)serviceClassChanged:(NSPopUpButton *)sender {
    NSInteger idx = [sender indexOfSelectedItem];
    _serviceClass = NotificationServiceClasses()[idx];
    _currentMode = [_serviceClass tempateFormat];

    [self.inputView setMode:_currentMode];
    [self.inputView setString:[_serviceClass reportTemplate]];
    [self renderToView:_inputView.string];
}

- (IBAction)themeChanged:(id)sender {
    [_inputView setTheme:[sender indexOfSelectedItem]];
    [[NSUserDefaults standardUserDefaults] setInteger:[sender indexOfSelectedItem] forKey:@"SyntaxEditorTheme"];
}

- (void)textDidChange:(NSNotification *)notification {
    [self renderToView:_inputView.string];

    // Defer once...
    if(_textDidChangeDidDefer){
        self.unsavedChanges.enabled = YES;
    }
    _textDidChangeDidDefer = YES;
}

- (NSString *)renderedText:(NSError *__autoreleasing*)error {
    if((_template = [GRMustacheTemplate templateFromString:_inputView.string error:error])){
        return [_template renderObject:self.exampleData error:error];
    }
    return nil;
}

- (BOOL)renderToView:(NSString *)text {
    NSError *error = nil;
    NSString *renderedText = [self renderedText:&error];
    if (renderedText) {
        if (_currentMode == ACEModeMarkdown) {
             renderedText = [MMMarkdown HTMLStringWithMarkdown:renderedText extensions:MMMarkdownExtensionsGitHubFlavored error:NULL];
        }
        [[self.renderView mainFrame] loadHTMLString:renderedText baseURL:[NSURL URLWithString:@"http://localhost"]];
    }
    _errorReport.stringValue = error ? error.localizedDescription : @"";
    return !error;
}

- (NSInteger)errorLine {
    NSArray *lines = [_errorReport.stringValue componentsSeparatedByString:@":"];
    if (lines.count > 1) {
        NSString *base = [lines.firstObject componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].lastObject;
        return base.integerValue;
    }
    return 0;
}

@end
