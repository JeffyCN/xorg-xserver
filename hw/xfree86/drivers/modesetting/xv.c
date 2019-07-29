/*
 *  Copyright (c) 2019, Fuzhou Rockchip Electronics Co., Ltd
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 */

#ifdef HAVE_DIX_CONFIG_H
#include "dix-config.h"
#endif

#include "driver.h"
#include "dumb_bo.h"
/*
#include "xf86.h"
*/

#include <stdio.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <libdrm/drm_fourcc.h>

#include <X11/extensions/Xv.h>
#include "fourcc.h"

#define NUM_FORMATS 4

static XF86VideoFormatRec Formats[NUM_FORMATS] = {
    {15, TrueColor}, {16, TrueColor}, {24, TrueColor}, {30, TrueColor}
};

#define MAKE_ATOM(a) MakeAtom(a, sizeof(a) - 1, TRUE)

XvAttributeRec ms_exa_xv_attributes[] = {
    {0, 0, 0, NULL}
};
int ms_exa_xv_num_attributes = ARRAY_SIZE(ms_exa_xv_attributes) - 1;

XvImageRec ms_exa_xv_images[] = {
    XVIMAGE_NV12
};
int ms_exa_xv_num_images = ARRAY_SIZE(ms_exa_xv_images);

#define ALIGN(i,m) (((i) + (m) - 1) & ~((m) - 1))

typedef struct {
} ms_exa_port_private;

static void
ms_exa_xv_stop_video(ScrnInfoPtr pScrn, void *data, Bool cleanup)
{
}

static int
ms_exa_xv_set_port_attribute(ScrnInfoPtr pScrn,
                             Atom attribute, INT32 value, void *data)
{
    return Success;
}

static int
ms_exa_xv_get_port_attribute(ScrnInfoPtr pScrn,
                             Atom attribute, INT32 *value, void *data)
{
    return Success;
}

static void
ms_exa_xv_query_best_size(ScrnInfoPtr pScrn,
                          Bool motion,
                          short vid_w, short vid_h,
                          short drw_w, short drw_h,
                          unsigned int *p_w, unsigned int *p_h, void *data)
{
    *p_w = drw_w;
    *p_h = drw_h;
}

static int
ms_exa_xv_query_image_attributes(ScrnInfoPtr pScrn,
                                 int id,
                                 unsigned short *w, unsigned short *h,
                                 int *pitches, int *offsets)
{
    int size = 0, tmp;

    if (offsets)
        offsets[0] = 0;

    if (id != FOURCC_NV12)
        return 0;

    *w = ALIGN(*w, 2);
    *h = ALIGN(*h, 2);
    size = ALIGN(*w, 4);
    if (pitches)
        pitches[0] = size;
    size *= *h;
    if (offsets)
        offsets[1] = size;
    tmp = ALIGN(*w, 4);
    if (pitches)
        pitches[1] = tmp;
    tmp *= (*h >> 1);
    size += tmp;

    return size;
}

static PixmapPtr
ms_exa_xv_create_pixmap(ScrnInfoPtr scrn, ms_exa_port_private *port_priv,
                        int id,
                        unsigned char *buf,
                        short width,
                        short height)
{
    ScreenPtr screen = scrn->pScreen;
    PixmapPtr pixmap;
    int pitch;

    pitch = ALIGN(width, 4) * 3 / 2;

    pixmap = drmmode_create_pixmap_header(screen, width, height,
                                          12, 12, pitch, buf);
    if (!pixmap)
        return NULL;

    pixmap->devKind = pitch;
    pixmap->devPrivate.ptr = buf;

    return pixmap;
}

static int
ms_exa_xv_put_image(ScrnInfoPtr pScrn,
                    short src_x, short src_y,
                    short drw_x, short drw_y,
                    short src_w, short src_h,
                    short drw_w, short drw_h,
                    int id,
                    unsigned char *buf,
                    short width,
                    short height,
                    Bool sync,
                    RegionPtr clipBoxes, void *data, DrawablePtr pDrawable)
{
    ms_exa_port_private *port_priv = data;
    ScreenPtr screen = pScrn->pScreen;
    PixmapPtr src_pixmap, dst_pixmap;
    pixman_f_transform_t transform;
    double sx, sy, tx, ty;
    int ret = Success;

    src_pixmap = ms_exa_xv_create_pixmap(pScrn, port_priv, id,
                                         buf, width, height);
    if (!src_pixmap)
        return BadMatch;

    if (pDrawable->type == DRAWABLE_WINDOW)
        dst_pixmap = screen->GetWindowPixmap((WindowPtr) pDrawable);
    else
        dst_pixmap = (PixmapPtr) pDrawable;

    DamageRegionAppend(pDrawable, clipBoxes);

    sx = (double)src_w / drw_w;
    sy = (double)src_h / drw_h;

    tx = drw_x - src_x;
    ty = drw_y - src_y;

#ifdef COMPOSITE
    RegionTranslate(clipBoxes, -dst_pixmap->screen_x, -dst_pixmap->screen_y);
    tx -= dst_pixmap->screen_x;
    ty -= dst_pixmap->screen_y;
#endif

    pixman_f_transform_init_scale(&transform, sx, sy);
    pixman_f_transform_translate(NULL, &transform, tx, ty);

    if (!ms_exa_copy_area(src_pixmap, dst_pixmap, &transform, clipBoxes))
        ret = BadMatch;

    DamageRegionProcessPending(pDrawable);

    screen->DestroyPixmap(src_pixmap);

    return ret;
}

static XF86VideoEncodingRec DummyEncoding[1] = {
    { 0, "XV_IMAGE", 8192, 8192, {1, 1} }
};

XF86VideoAdaptorPtr
ms_exa_xv_init(ScreenPtr screen, int num_texture_ports)
{
    ms_exa_port_private *port_priv;
    XF86VideoAdaptorPtr adapt;
    int i;

    adapt = calloc(1, sizeof(XF86VideoAdaptorRec) + num_texture_ports *
                   (sizeof(ms_exa_port_private) + sizeof(DevUnion)));
    if (adapt == NULL)
        return NULL;

    adapt->type = XvWindowMask | XvInputMask | XvImageMask;
    adapt->flags = 0;
    adapt->name = "Modesetting Textured Video";
    adapt->nEncodings = 1;
    adapt->pEncodings = DummyEncoding;

    adapt->nFormats = NUM_FORMATS;
    adapt->pFormats = Formats;
    adapt->nPorts = num_texture_ports;
    adapt->pPortPrivates = (DevUnion *) (&adapt[1]);

    adapt->pAttributes = ms_exa_xv_attributes;
    adapt->nAttributes = ms_exa_xv_num_attributes;

    port_priv =
        (ms_exa_port_private *) (&adapt->pPortPrivates[num_texture_ports]);

    adapt->pImages = ms_exa_xv_images;
    adapt->nImages = ms_exa_xv_num_images;

    adapt->PutVideo = NULL;
    adapt->PutStill = NULL;
    adapt->GetVideo = NULL;
    adapt->GetStill = NULL;
    adapt->StopVideo = ms_exa_xv_stop_video;
    adapt->SetPortAttribute = ms_exa_xv_set_port_attribute;
    adapt->GetPortAttribute = ms_exa_xv_get_port_attribute;
    adapt->QueryBestSize = ms_exa_xv_query_best_size;
    adapt->PutImage = ms_exa_xv_put_image;
    adapt->ReputImage = NULL;
    adapt->QueryImageAttributes = ms_exa_xv_query_image_attributes;

    for (i = 0; i < num_texture_ports; i++) {
        ms_exa_port_private *priv = &port_priv[i];

        adapt->pPortPrivates[i].ptr = (void *) (priv);
    }
    return adapt;
}
