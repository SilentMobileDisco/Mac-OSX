//
//  ViewController.h
//  Silent Mobile DJ
//
//  Created by Oren Berkowitz on 5/14/16.
//  Copyright © 2016 Oren Berkowitz. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ViewController : NSViewController

@property (weak) IBOutlet NSTextField *name;
@property (weak) IBOutlet NSTextField *message_label;

- (IBAction) onPlay:(id) sender;

@end

