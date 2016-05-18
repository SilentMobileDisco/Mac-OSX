//
//  ViewController.m
//  Silent Mobile DJ
//
//  Created by Oren Berkowitz on 5/14/16.
//  Copyright © 2016 Oren Berkowitz. All rights reserved.
//

#import "ViewController.h"
#import "GStreamerBackend.h"
#import "GStreamerBackendDelegate.h"

#import <gst/gst.h>
#include <gst/sdp/gstsdpmessage.h>
#include <gst/rtsp-server/rtsp-server.h>

@interface ViewController () <NSNetServiceDelegate, GStreamerBackendDelegate>

@property (strong, nonatomic) NSNetService *service;

@end

@implementation ViewController
GStreamerBackend *gst_backend;

- (void)viewDidLoad {
    [super viewDidLoad];
    gst_backend = [[GStreamerBackend alloc] init];
    gst_backend = [gst_backend init:self];
}
- (IBAction) onPlay:(id) sender
{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self startBroadcastWithName:[_name stringValue] baseTime:gst_backend.base_time];
        
        [self gstPlay:[_name stringValue]];
    });
}

- (void) gstPlay:(NSString *) name
{
    [gst_backend play];
}

#pragma mark -
#pragma mark Helper Methods
- (void)startBroadcastWithName:(NSString*)name baseTime:(NSUInteger)baseTime {
    
    // Initialize Service
    self.service = [[NSNetService alloc] initWithDomain:@"local." type:@"_silentmobiledisco._udp." name:name port:8554];

    NSMutableDictionary* dic = [NSMutableDictionary dictionary];
    [dic setValue:[gst_backend getCaps] forKey:@"caps"];
    [self.service setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:dic]];
    
    // Configure Service
    [self.service setDelegate:self];
    
    // Publish Servibonce
    [self.service publish];
    
}

-(void)gstreamerSetUIMessage:(NSString *)message {
    self.message_label = message;
}


@end
