#include "CoreEngine.h"

#include <algorithm>
#include <cmath>
#include <numbers>

namespace {

constexpr double kEpsilon = 1e-9;
constexpr double kQuarterPi = std::numbers::pi / 4.0;

CEPoint midpoint(CEPoint a, CEPoint b) {
    return CEPoint{(a.x + b.x) * 0.5, (a.y + b.y) * 0.5};
}

double point_to_segment_distance(CEPoint p, CEPoint a, CEPoint b) {
    const double dx = b.x - a.x;
    const double dy = b.y - a.y;
    const double length_sq = dx * dx + dy * dy;
    if (length_sq <= kEpsilon) {
        return std::hypot(p.x - a.x, p.y - a.y);
    }
    const double projection = ((p.x - a.x) * dx + (p.y - a.y) * dy) / length_sq;
    const double t = std::clamp(projection, 0.0, 1.0);
    const double closest_x = a.x + t * dx;
    const double closest_y = a.y + t * dy;
    return std::hypot(p.x - closest_x, p.y - closest_y);
}

CERect normalize_rect(CERect rect) {
    const double min_x = std::min(rect.x, rect.x + rect.width);
    const double max_x = std::max(rect.x, rect.x + rect.width);
    const double min_y = std::min(rect.y, rect.y + rect.height);
    const double max_y = std::max(rect.y, rect.y + rect.height);
    return CERect{min_x, min_y, max_x - min_x, max_y - min_y};
}

bool point_in_rect(CEPoint p, CERect r) {
    return p.x >= r.x && p.x <= (r.x + r.width) && p.y >= r.y && p.y <= (r.y + r.height);
}

bool segment_intersects_rect(CEPoint p0, CEPoint p1, CERect r) {
    if (point_in_rect(p0, r) || point_in_rect(p1, r)) {
        return true;
    }
    const double dx = p1.x - p0.x;
    const double dy = p1.y - p0.y;
    const double p[4] = {-dx, dx, -dy, dy};
    const double q[4] = {
        p0.x - r.x,
        (r.x + r.width) - p0.x,
        p0.y - r.y,
        (r.y + r.height) - p0.y
    };

    double u1 = 0.0;
    double u2 = 1.0;
    for (int i = 0; i < 4; ++i) {
        if (std::abs(p[i]) <= kEpsilon) {
            if (q[i] < 0.0) {
                return false;
            }
        } else {
            const double t = q[i] / p[i];
            if (p[i] < 0.0) {
                u1 = std::max(u1, t);
            } else {
                u2 = std::min(u2, t);
            }
            if (u1 > u2) {
                return false;
            }
        }
    }
    return true;
}

}

extern "C" {

size_t ce_smooth_stroke(const CEPoint* input, size_t count, CEPoint* output, size_t max_output) {
    const bool has_valid_buffers = input != nullptr && output != nullptr;
    const bool has_capacity = count > 0 && max_output > 0;
    if (!has_valid_buffers || !has_capacity) {
        return 0;
    }

    if (count < 3) {
        const size_t copy_count = std::min(count, max_output);
        for (size_t i = 0; i < copy_count; ++i) {
            output[i] = input[i];
        }
        return copy_count;
    }

    size_t written = 0;
    output[written++] = input[0];

    constexpr int kSubdivisions = 4;
    for (size_t i = 1; i + 1 < count && written < max_output; ++i) {
        const CEPoint start_anchor = (i == 1) ? input[0] : midpoint(input[i - 1], input[i]);
        const CEPoint end_anchor = (i + 2 == count) ? input[count - 1] : midpoint(input[i], input[i + 1]);
        const CEPoint control = input[i];

        for (int step = 1; step <= kSubdivisions && written < max_output; ++step) {
            const double t = static_cast<double>(step) / static_cast<double>(kSubdivisions);
            const double one_minus_t = 1.0 - t;
            const double w0 = one_minus_t * one_minus_t;
            const double w1 = 2.0 * one_minus_t * t;
            const double w2 = t * t;
            output[written++] = CEPoint{
                w0 * start_anchor.x + w1 * control.x + w2 * end_anchor.x,
                w0 * start_anchor.y + w1 * control.y + w2 * end_anchor.y
            };
        }
    }

    return written;
}

CEPoint ce_constrain_line(CEPoint start, CEPoint end) {
    const double dx = end.x - start.x;
    const double dy = end.y - start.y;
    const double length = std::hypot(dx, dy);
    if (length <= kEpsilon) {
        return start;
    }

    const double angle = std::atan2(dy, dx);
    const double snapped_angle = std::round(angle / kQuarterPi) * kQuarterPi;
    double cos_val = std::cos(snapped_angle);
    double sin_val = std::sin(snapped_angle);
    if (std::abs(cos_val) < 1e-12) {
        cos_val = 0.0;
    }
    if (std::abs(sin_val) < 1e-12) {
        sin_val = 0.0;
    }

    return CEPoint{
        start.x + length * cos_val,
        start.y + length * sin_val
    };
}

CERect ce_make_rect(CEPoint start, CEPoint end, bool constrain_square) {
    double target_x = end.x;
    double target_y = end.y;
    const double dx = end.x - start.x;
    const double dy = end.y - start.y;

    if (constrain_square) {
        const double side = std::max(std::abs(dx), std::abs(dy));
        target_x = start.x + (dx >= 0.0 ? side : -side);
        target_y = start.y + (dy >= 0.0 ? side : -side);
    }

    const double min_x = std::min(start.x, target_x);
    const double min_y = std::min(start.y, target_y);
    return CERect{
        min_x,
        min_y,
        std::abs(target_x - start.x),
        std::abs(target_y - start.y)
    };
}

size_t ce_build_arrow_polygon(CEPoint start, CEPoint end, double line_weight, CEPoint* out_points, size_t max_points) {
    if (out_points == nullptr || max_points < 7) {
        return 0;
    }

    const double weight = std::max(1.0, line_weight);
    const double dx = end.x - start.x;
    const double dy = end.y - start.y;
    const double length = std::hypot(dx, dy);

    const double ux = (length > kEpsilon) ? (dx / length) : 1.0;
    const double uy = (length > kEpsilon) ? (dy / length) : 0.0;
    const double px = -uy;
    const double py = ux;

    const double desired_head_length = std::max(weight * 3.0, 12.0);
    const double head_length = (length > kEpsilon) ? std::min(length * 0.65, desired_head_length) : desired_head_length;
    const double head_half_width = std::max(weight * 1.8, 7.0);
    const double shaft_half_width = weight * 0.5;

    const CEPoint neck{
        end.x - ux * head_length,
        end.y - uy * head_length
    };

    out_points[0] = CEPoint{start.x + px * shaft_half_width, start.y + py * shaft_half_width};
    out_points[1] = CEPoint{neck.x + px * shaft_half_width, neck.y + py * shaft_half_width};
    out_points[2] = CEPoint{neck.x + px * head_half_width, neck.y + py * head_half_width};
    out_points[3] = end;
    out_points[4] = CEPoint{neck.x - px * head_half_width, neck.y - py * head_half_width};
    out_points[5] = CEPoint{neck.x - px * shaft_half_width, neck.y - py * shaft_half_width};
    out_points[6] = CEPoint{start.x - px * shaft_half_width, start.y - py * shaft_half_width};
    return 7;
}

size_t ce_build_shape_polygon(int shape_kind, CERect bounds, CEPoint* out_points, size_t max_points) {
    const CERect norm = normalize_rect(bounds);
    const bool has_valid_bounds = norm.width > 0.0 && norm.height > 0.0;
    if (out_points == nullptr || max_points == 0 || !has_valid_bounds) {
        return 0;
    }

    if (shape_kind == 2) {
        if (max_points < 4) {
            return 0;
        }
        out_points[0] = CEPoint{norm.x, norm.y};
        out_points[1] = CEPoint{norm.x + norm.width, norm.y};
        out_points[2] = CEPoint{norm.x + norm.width, norm.y + norm.height};
        out_points[3] = CEPoint{norm.x, norm.y + norm.height};
        return 4;
    }

    if (shape_kind == 3) {
        if (max_points < 4) {
            return 0;
        }
        const double cx = norm.x + norm.width * 0.5;
        const double cy = norm.y + norm.height * 0.5;
        out_points[0] = CEPoint{cx, norm.y};
        out_points[1] = CEPoint{norm.x + norm.width, cy};
        out_points[2] = CEPoint{cx, norm.y + norm.height};
        out_points[3] = CEPoint{norm.x, cy};
        return 4;
    }

    if (shape_kind == 0 || shape_kind == 1) {
        if (max_points < 8) {
            return 0;
        }
        const size_t steps = std::min<size_t>(max_points, 64);
        const double cx = norm.x + norm.width * 0.5;
        const double cy = norm.y + norm.height * 0.5;
        const double rx = norm.width * 0.5;
        const double ry = norm.height * 0.5;

        for (size_t i = 0; i < steps; ++i) {
            const double angle = (2.0 * std::numbers::pi * static_cast<double>(i)) / static_cast<double>(steps);
            const double cos_a = std::cos(angle);
            const double sin_a = std::sin(angle);
            if (shape_kind == 0) {
                out_points[i] = CEPoint{cx + rx * cos_a, cy + ry * sin_a};
            } else {
                const double sx = (cos_a >= 0.0 ? 1.0 : -1.0) * std::sqrt(std::abs(cos_a));
                const double sy = (sin_a >= 0.0 ? 1.0 : -1.0) * std::sqrt(std::abs(sin_a));
                out_points[i] = CEPoint{cx + rx * sx, cy + ry * sy};
            }
        }
        return steps;
    }

    return 0;
}

bool ce_hit_test_stroke(const CEPoint* points, size_t count, double line_weight, CEPoint test_point, double tolerance) {
    if (points == nullptr || count == 0) {
        return false;
    }

    const double threshold = std::max(0.0, line_weight) * 0.5 + std::max(0.0, tolerance);
    if (count == 1) {
        return std::hypot(test_point.x - points[0].x, test_point.y - points[0].y) <= threshold;
    }

    for (size_t i = 0; i + 1 < count; ++i) {
        if (point_to_segment_distance(test_point, points[i], points[i + 1]) <= threshold) {
            return true;
        }
    }
    return false;
}

bool ce_hit_test_rect(CERect rect, bool is_filled, double line_weight, CEPoint test_point, double tolerance) {
    const CERect norm = normalize_rect(rect);
    const double threshold = std::max(0.0, line_weight) * 0.5 + std::max(0.0, tolerance);

    const CERect outer{
        norm.x - threshold,
        norm.y - threshold,
        norm.width + threshold * 2.0,
        norm.height + threshold * 2.0
    };
    if (!point_in_rect(test_point, outer)) {
        return false;
    }
    if (is_filled) {
        return true;
    }

    const double inner_w = norm.width - threshold * 2.0;
    const double inner_h = norm.height - threshold * 2.0;
    if (inner_w <= 0.0 || inner_h <= 0.0) {
        return true;
    }
    const CERect inner{norm.x + threshold, norm.y + threshold, inner_w, inner_h};
    return !point_in_rect(test_point, inner);
}

bool ce_rect_intersects_stroke(CERect marquee, const CEPoint* points, size_t count) {
    if (points == nullptr || count == 0) {
        return false;
    }
    const CERect norm = normalize_rect(marquee);
    if (count == 1) {
        return point_in_rect(points[0], norm);
    }
    for (size_t i = 0; i + 1 < count; ++i) {
        if (segment_intersects_rect(points[i], points[i + 1], norm)) {
            return true;
        }
    }
    return false;
}

CERect ce_compute_bounding_box(const CEPoint* points, size_t count, double line_weight) {
    if (points == nullptr || count == 0) {
        return CERect{0.0, 0.0, 0.0, 0.0};
    }

    double min_x = points[0].x;
    double max_x = points[0].x;
    double min_y = points[0].y;
    double max_y = points[0].y;

    for (size_t i = 1; i < count; ++i) {
        min_x = std::min(min_x, points[i].x);
        max_x = std::max(max_x, points[i].x);
        min_y = std::min(min_y, points[i].y);
        max_y = std::max(max_y, points[i].y);
    }

    const double pad = std::max(0.0, line_weight) * 0.5;
    return CERect{
        min_x - pad,
        min_y - pad,
        (max_x - min_x) + pad * 2.0,
        (max_y - min_y) + pad * 2.0
    };
}

bool ce_is_stroke_expired(double created_at_sec, double current_time_sec, double delay_sec, bool auto_erase_enabled) {
    if (!auto_erase_enabled) {
        return false;
    }
    const double effective_delay = std::max(0.1, delay_sec);
    return (current_time_sec - created_at_sec) >= effective_delay;
}

}
