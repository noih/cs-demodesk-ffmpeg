#!/bin/bash
# Sourced as a BtbN build add-in, before dependency enable flags are appended.
FF_CONFIGURE+=' --disable-autodetect --disable-everything --disable-network --disable-ffplay --disable-doc'
FF_CONFIGURE+=' --enable-ffmpeg --enable-ffprobe --enable-avcodec --enable-avformat --enable-avfilter --enable-swscale --enable-swresample'
FF_CONFIGURE+=' --enable-nvenc'
FF_CONFIGURE+=' --enable-protocol=file,pipe --enable-indev=lavfi'
FF_CONFIGURE+=' --enable-demuxer=mov,matroska,avi,wav,rawvideo,concat'
FF_CONFIGURE+=' --enable-muxer=mp4,mov,matroska,wav,rawvideo,null'
FF_CONFIGURE+=' --enable-decoder=h264,hevc,libdav1d,aac,pcm_s16le,pcm_s24le,pcm_s32le,pcm_f32le,rawvideo,wrapped_avframe'
FF_CONFIGURE+=' --enable-encoder=libx264,libx265,libsvtav1,h264_nvenc,hevc_nvenc,av1_nvenc,aac,pcm_s16le,rawvideo,wrapped_avframe'
FF_CONFIGURE+=' --enable-parser=h264,hevc,av1,aac'
FF_CONFIGURE+=' --enable-bsf=aac_adtstoasc,h264_mp4toannexb,hevc_mp4toannexb,extract_extradata,av1_metadata'
FF_CONFIGURE+=' --enable-filter=scale,format,fps,null,anull,aformat,aresample,apad,trim,atrim,setpts,asetpts,concat,color,testsrc2,sine'
