#ifndef CORE_ENGINE_H
#define CORE_ENGINE_H

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    double x;
    double y;
} CEPoint;

typedef struct {
    double x;
    double y;
    double width;
    double height;
} CERect;

size_t ce_smooth_stroke(const CEPoint* input, size_t count, CEPoint* output, size_t max_output);
CEPoint ce_constrain_line(CEPoint start, CEPoint end);
CERect ce_make_rect(CEPoint start, CEPoint end, bool constrain_square);
size_t ce_build_arrow_polygon(CEPoint start, CEPoint end, double line_weight, CEPoint* out_points, size_t max_points);
size_t ce_build_shape_polygon(int shape_kind, CERect bounds, CEPoint* out_points, size_t max_points);
bool ce_hit_test_stroke(const CEPoint* points, size_t count, double line_weight, CEPoint test_point, double tolerance);
bool ce_hit_test_rect(CERect rect, bool is_filled, double line_weight, CEPoint test_point, double tolerance);
bool ce_rect_intersects_stroke(CERect marquee, const CEPoint* points, size_t count);
CERect ce_compute_bounding_box(const CEPoint* points, size_t count, double line_weight);
bool ce_is_stroke_expired(double created_at_sec, double current_time_sec, double delay_sec, bool auto_erase_enabled);

#ifdef __cplusplus
}
#endif

#endif
