#import "GStreamerBackend.h"

#include <gst/gst.h>
#include <gst/net/gstnet.h>
#include <gst/net/gstnettimeprovider.h>
#include <string.h>
#include <math.h>


GST_DEBUG_CATEGORY_STATIC (debug_category);
#define GST_CAT_DEFAULT debug_category

@interface GStreamerBackend()
-(void)setUIMessage:(gchar*) message;
-(void)app_function;
-(void)check_initialization_complete_with_ip:(NSString*) ip port:(NSString*) port;
@end

/* change this to send the RTP data and RTCP to another host */
// #define DEST_HOST "127.0.0.1"
#define DEST_HOST "239.255.42.99"

/* #define AUDIO_SRC  "alsasrc" */
// ASOURCE="filesrc location=/Users/oberkowitz/Lofticries.mp3 ! mpegaudioparse ! mad ! audioconvert ! audioresample"

#define AUDIO_SRC  "audiotestsrc"
//#define AUDIO_SRC  "filesrc"

/* the encoder and payloader elements */
#define AUDIO_ENC  "alawenc"
#define AUDIO_PAY  "rtppcmapay"


@implementation GStreamerBackend {
    id ui_delegate;        /* Class that we use to interact with the user interface */
    GstElement *pipeline;  /* The running pipeline */
    GMainContext *context; /* GLib context used to run the main loop */
    GMainLoop *main_loop;  /* GLib main loop */
    gboolean initialized;  /* To avoid informing the UI multiple times about the initialization */
    GstClock *global_clock;/* The Clock exported on the network for synchronization */
    
}

/*
 * Interface methods
 */

-(id) init:(id) uiDelegate
{
    if (self = [super init])
    {
        self->ui_delegate = uiDelegate;
        
        GST_DEBUG_CATEGORY_INIT (debug_category, "silent-disco", 0, "silent-disco");
        gst_debug_set_threshold_for_name("silent-disco", GST_LEVEL_DEBUG);
        gst_debug_set_default_threshold(GST_LEVEL_DEBUG);
        
        /* Start the bus monitoring task */
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self app_function];
        });
    }
    
    return self;
}

-(void) dealloc
{
    if (pipeline) {
        GST_DEBUG("Setting the pipeline to NULL");
        gst_element_set_state(pipeline, GST_STATE_NULL);
        gst_object_unref(pipeline);
        pipeline = NULL;
    }
}

-(void) play
{
    if(gst_element_set_state(pipeline, GST_STATE_PLAYING) == GST_STATE_CHANGE_FAILURE) {
        [self setUIMessage:"Failed to set pipeline to playing"];
    }
}

-(void) pause
{
    if(gst_element_set_state(pipeline, GST_STATE_PAUSED) == GST_STATE_CHANGE_FAILURE) {
        [self setUIMessage:"Failed to set pipeline to paused"];
    }
}

/*
 * Private methods
 */

/* Change the message on the UI through the UI delegate */
-(void)setUIMessage:(gchar*) message
{
    NSString *string = [NSString stringWithUTF8String:message];
    if(ui_delegate && [ui_delegate respondsToSelector:@selector(gstreamerSetUIMessage:)])
    {
        [ui_delegate gstreamerSetUIMessage:string];
    }
}

static void
print_source_stats (GObject * source)
{
    GstStructure *stats;
    gchar *str;
    
    /* get the source stats */
    g_object_get (source, "stats", &stats, NULL);
    
    /* simply dump the stats structure */
    str = gst_structure_to_string (stats);
    g_print ("source stats: %s\n", str);
    
    gst_structure_free (stats);
    g_free (str);
}

/* this function is called every second and dumps the RTP manager stats */
static gboolean
print_stats (GstElement * rtpbin)
{
    GObject *session;
    GValueArray *arr;
    GValue *val;
    guint i;
    
    g_print ("***********************************\n");
    
    /* get session 0 */
    g_signal_emit_by_name (rtpbin, "get-internal-session", 0, &session);
    
    /* print all the sources in the session, this includes the internal source */
    g_object_get (session, "sources", &arr, NULL);
    
    for (i = 0; i < arr->n_values; i++) {
        GObject *source;
        
        val = g_value_array_get_nth (arr, i);
        source = g_value_get_object (val);
        
        print_source_stats (source);
    }
    g_value_array_free (arr);
    
    g_object_unref (session);
    
    return TRUE;
}



/* Check if all conditions are met to report GStreamer as initialized.
 * These conditions will change depending on the application */
-(void)check_initialization_complete_with_ip:(NSString*) ip port:(NSString*) port
{
    if (!initialized && main_loop) {
        GST_DEBUG ("Initialization complete, notifying application.");
        if (ui_delegate && [ui_delegate respondsToSelector:@selector(gstreamerInitialized)])
        {
            [ui_delegate gstreamerInitialized];
            [self setUIMessage:[[NSString stringWithFormat:@"Ready: %@:%@", ip, port] UTF8String]];
        }
        initialized = TRUE;
    }
}

/* Main method for the bus monitoring code */
-(void) app_function
{
    GstElement *audiosrc, *audioconv, *audiores, *audioenc, *audiopay;
    GstElement *mpegparse, *mad;
    GstElement *rtpbin, *rtpsink, *rtcpsink, *rtcpsrc;
    GMainLoop *loop;
    GstPad *srcpad, *sinkpad;
    
    /* always init first */
    
    /* the pipeline to hold everything */
    pipeline = gst_pipeline_new (NULL);
    g_assert (pipeline);
    
    /* the audio capture and format conversion */
    audiosrc = gst_element_factory_make (AUDIO_SRC, "audiosrc");
    // For filesrc, set the location:
//    g_object_set(audiosrc, "location", "/Users/oberkowitz/Lofticries.mp3", NULL);
    g_assert (audiosrc);
    
    // MP3 stuff, comment out if you aren't using mp3
//    mpegparse = gst_element_factory_make("mpegaudioparse", "mpegparse");
//    g_assert(mpegparse);
//    mad = gst_element_factory_make("mad", "mad");
//    g_assert(mad);
    
    audioconv = gst_element_factory_make ("audioconvert", "audioconv");
    g_assert (audioconv);
    audiores = gst_element_factory_make ("audioresample", "audiores");
    g_assert (audiores);
    /* the encoding and payloading */
    audioenc = gst_element_factory_make (AUDIO_ENC, "audioenc");
    g_assert (audioenc);
    audiopay = gst_element_factory_make (AUDIO_PAY, "audiopay");
    g_assert (audiopay);
    
    /* add capture and payloading to the pipeline and link */
    // MP3 add many line, comment this out if using an audio src element.
     gst_bin_add_many (GST_BIN (pipeline), audiosrc, audioconv, audiores, audioenc, audiopay, NULL);
//    gst_bin_add_many (GST_BIN (pipeline), audiosrc, mpegparse, mad, audioconv, audiores, audioenc, audiopay, NULL);
    
     if (!gst_element_link_many (audiosrc, audioconv, audiores, audioenc,
//    if (!gst_element_link_many (audiosrc, mpegparse, mad, audioconv, audiores, audioenc,
                                audiopay, NULL)) {
        g_error ("Failed to link audiosrc, audioconv, audioresample, "
                 "audio encoder and audio payloader");
    }
    
    /* the rtpbin element */
    rtpbin = gst_element_factory_make ("rtpbin", "rtpbin");
    g_assert (rtpbin);
    
    gst_bin_add (GST_BIN (pipeline), rtpbin);
    
    /* the udp sinks and source we will use for RTP and RTCP */
    rtpsink = gst_element_factory_make ("udpsink", "rtpsink");
    g_assert (rtpsink);
    g_object_set (rtpsink, "port", 5002, "host", DEST_HOST, NULL);
    
    rtcpsink = gst_element_factory_make ("udpsink", "rtcpsink");
    g_assert (rtcpsink);
    g_object_set (rtcpsink, "port", 5003, "host", DEST_HOST, NULL);
    /* no need for synchronisation or preroll on the RTCP sink */
    g_object_set (rtcpsink, "async", FALSE, "sync", FALSE, NULL);
    
    rtcpsrc = gst_element_factory_make ("udpsrc", "rtcpsrc");
    g_assert (rtcpsrc);
    g_object_set (rtcpsrc, "port", 5007, NULL);
    
    gst_bin_add_many (GST_BIN (pipeline), rtpsink, rtcpsink, rtcpsrc, NULL);
    
    /* now link all to the rtpbin, start by getting an RTP sinkpad for session 0 */
    sinkpad = gst_element_get_request_pad (rtpbin, "send_rtp_sink_0");
    srcpad = gst_element_get_static_pad (audiopay, "src");
    if (gst_pad_link (srcpad, sinkpad) != GST_PAD_LINK_OK)
        g_error ("Failed to link audio payloader to rtpbin");
    gst_object_unref (srcpad);
    
    /* get the RTP srcpad that was created when we requested the sinkpad above and
     * link it to the rtpsink sinkpad*/
    srcpad = gst_element_get_static_pad (rtpbin, "send_rtp_src_0");
    sinkpad = gst_element_get_static_pad (rtpsink, "sink");
    if (gst_pad_link (srcpad, sinkpad) != GST_PAD_LINK_OK)
        g_error ("Failed to link rtpbin to rtpsink");
    gst_object_unref (srcpad);
    gst_object_unref (sinkpad);
    
    /* get an RTCP srcpad for sending RTCP to the receiver */
    srcpad = gst_element_get_request_pad (rtpbin, "send_rtcp_src_0");
    sinkpad = gst_element_get_static_pad (rtcpsink, "sink");
    if (gst_pad_link (srcpad, sinkpad) != GST_PAD_LINK_OK)
        g_error ("Failed to link rtpbin to rtcpsink");
    gst_object_unref (sinkpad);
    
    /* we also want to receive RTCP, request an RTCP sinkpad for session 0 and
     * link it to the srcpad of the udpsrc for RTCP */
    srcpad = gst_element_get_static_pad (rtcpsrc, "src");
    sinkpad = gst_element_get_request_pad (rtpbin, "recv_rtcp_sink_0");
    if (gst_pad_link (srcpad, sinkpad) != GST_PAD_LINK_OK)
        g_error ("Failed to link rtcpsrc to rtpbin");
    gst_object_unref (srcpad);
    
    /* set the pipeline to playing */
    g_print ("starting sender pipeline\n");
    gst_element_set_state (pipeline, GST_STATE_PLAYING);
    
    /* print stats every second */
    g_timeout_add_seconds (1, (GSourceFunc) print_stats, rtpbin);
    
    /* we need to run a GLib main loop to get the messages */
    loop = g_main_loop_new (NULL, FALSE);
    
    [self getCaps];
    
    /* Set the clock for the pipeline */
    global_clock = gst_system_clock_obtain ();
    gst_net_time_provider_new (global_clock, "0.0.0.0", 8554);
    gst_pipeline_set_clock((GstPipeline *) pipeline, global_clock);
    
    // Run the loop
    g_main_loop_run (loop);
    
    g_print ("stopping sender pipeline\n");
    gst_element_set_state (pipeline, GST_STATE_NULL);
    
    
}

-(NSString *)getCaps
{
    GstPad *sinkpad;
    GstElement *rtpsink;
    GstCaps *caps;
    guint size;
    
    rtpsink = gst_bin_get_by_name(GST_BIN (pipeline), "rtpsink");
    sinkpad = gst_element_get_static_pad (rtpsink, "sink");
    caps = gst_pad_get_allowed_caps(sinkpad);
    
    size = gst_caps_get_size(caps);
    GstStructure *str = gst_caps_get_structure (caps, 0);

    gst_object_unref(rtpsink);
    gst_object_unref(sinkpad);
    GValue *val  = gst_structure_get_value(str, "media");
    NSString *value = [NSString stringWithUTF8String:g_value_get_string(val)];
    return [NSString stringWithUTF8String:gst_caps_to_string(caps)];
}
//-(void) app_function_orig
//
//{
//    GMainLoop *loop;
//    GstRTSPServer *server;
//    GstRTSPMountPoints *mounts;
//    GstRTSPMediaFactory *factory;
//    gchar *str;
//
//
//    loop = g_main_loop_new (NULL, FALSE);
//
//    /* create a server instance */
//    server = gst_rtsp_server_new ();
//
//    /* get the mount points for this server, every server has a default object
//     * that be used to map uri mount points to media factories */
//    mounts = gst_rtsp_server_get_mount_points (server);
//
//    factory = gst_rtsp_media_factory_new ();
//    str = g_strdup_printf ("( "
//                           //                                 "filesrc location=\"%s\" ! mpegaudioparse ! queue ! rtpmpapay pt=96 name=pay0 " ")", argv[1]);
//                           "jackaudiosrc ! audioconvert ! audioresample ! alawenc ! rtppcmapay pt=96 name=pay0 " ")");
//
//    gst_rtsp_media_factory_set_launch (factory, str);
//
//    gst_rtsp_media_factory_set_latency(factory, 25);
//    gst_rtsp_media_factory_set_shared (factory, TRUE);
//
//    g_signal_connect (factory, "media-constructed", (GCallback)
//                      media_constructed, NULL);
//
//    //    g_signal_connect (G_OBJECT (bus), "message::error", (GCallback)error_cb, (__bridge void *)self);
//
//    /* attach the test factory to the /test url */
//    gst_rtsp_mount_points_add_factory (mounts, "/disco", factory);
//
//    /* don't need the ref to the mapper anymore */
//    g_object_unref (mounts);
//
//    /* attach the server to the default maincontext */
//    if (gst_rtsp_server_attach (server, NULL) == 0)
//        return;
//
//    g_timeout_add_seconds (2, (GSourceFunc) time_out, server);
//
//    /* start serving */
////    [self check_initialization_complete_with_ip:@"127.0.0.1" port:@"8554"];
//    [self setUIMessage:"starting the server"];
//    g_print ("stream ready at rtsp://127.0.0.1:8554/disco\n");
//    g_main_loop_run (loop);
//    GST_DEBUG ("Exited main loop");
//    g_main_loop_unref (main_loop);
//    main_loop = NULL;
//
//    /* Free resources */
//    g_main_context_pop_thread_default(context);
//    g_main_context_unref (context);
//    gst_element_set_state (pipeline, GST_STATE_NULL);
//    gst_object_unref (pipeline);
//
//    return;
//
//
//}

@end

