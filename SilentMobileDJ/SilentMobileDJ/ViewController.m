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
        [self startBroadcast:[_name stringValue]];
        
        [self gstPlay:[_name stringValue]];
    });
}

static gboolean time_out (GstRTSPServer *server)
{
    GstRTSPSessionPool *pool;
    
    pool = gst_rtsp_server_get_session_pool (server);
    gst_rtsp_session_pool_cleanup (pool);
    g_object_unref (pool);
    
    return TRUE;
}

static void
media_constructed (GstRTSPMediaFactory * factory, GstRTSPMedia * media)
{
    guint i, n_streams;
    
    n_streams = gst_rtsp_media_n_streams (media);
    
    for (i = 0; i < n_streams; i++) {
        GstRTSPAddressPool *pool;
        GstRTSPStream *stream;
        gchar *min, *max;
        
        stream = gst_rtsp_media_get_stream (media, i);
        
        /* make a new address pool */
        pool = gst_rtsp_address_pool_new ();
        
        min = g_strdup_printf ("224.3.0.%d", (2 * i) + 1);
        max = g_strdup_printf ("224.3.0.%d", (2 * i) + 2);
        gst_rtsp_address_pool_add_range (pool, min, max,
                                         5000 + (10 * i), 5010 + (10 * i), 1);
        g_free (min);
        g_free (max);
        
        gst_rtsp_stream_set_address_pool (stream, pool);
        g_object_unref (pool);
    }
}

- (void) gstPlay:(NSString *) name
{
    [gst_backend play];
}

#pragma mark -
#pragma mark Helper Methods
- (void)startBroadcast: (NSString*)name {
    
    // Initialize Service
    self.service = [[NSNetService alloc] initWithDomain:@"local." type:@"_silentmobiledisco._udp." name:name port:8554];
    
    // Configure Service
    [self.service setDelegate:self];
    
    // Publish Servibonce
    [self.service publish];
    
}

-(void)gstreamerSetUIMessage:(NSString *)message {
    self.message_label = message;
}


@end
