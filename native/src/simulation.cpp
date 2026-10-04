#include <algorithm>
#include <cmath>
#include <deque>
#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <godot_cpp/classes/random_number_generator.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/triangle_mesh.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <unordered_map>
#include <vector>
using namespace godot;
namespace {
double number(Object *o, const char *name) { return double(o->get(name)); }
Vector3 vector(Object *o, const char *name) { return o->get(name); }
bool flag(Object *o, const char *name) { return bool(o->get(name)); }
Object *object(Object *o, const char *name) { return o->get(name); }
double clamp(double x, double a, double b) { return std::max(a, std::min(x, b)); }
Vector3 limited(Vector3 v, double length = 1) {
    double l = v.length();
    return l > length ? v * (length / l) : v;
}
struct Cell {
    int x, y, z;
    bool operator==(const Cell &o) const { return x == o.x && y == o.y && z == o.z; }
};
struct Hash {
    size_t operator()(const Cell &c) const {
        return uint64_t(uint32_t(c.x)) * 73856093 ^ uint64_t(uint32_t(c.y)) * 19349663 ^
               uint64_t(uint32_t(c.z)) * 83492791;
    }
};
Cell cell(Vector3 p, double s) {
    return {int(std::floor(p.x / s)), int(std::floor(p.y / s)), int(std::floor(p.z / s))};
}
struct Ship {
    Node3D *node = nullptr;
    Vector3 pos, previous, up, forward, view, velocity, spin, separation;
    Quaternion rotation;
    double altitude = 0, yaw = 0, desired = 0, pressure = 0;
    bool alive = false;
};
struct Settings {
    double mass, horizontal, vertical, hd, vd, inertia, turn, yd, angular_inertia, frequency, clearance,
        spring, damping, maximum;
    explicit Settings(Object *s)
        : mass(std::max(number(s, "mass"), .001)), horizontal(number(s, "horizontal_thrust_force")),
          vertical(number(s, "vertical_thrust_force")), hd(number(s, "horizontal_damping")),
          vd(number(s, "vertical_damping")), inertia(std::max(number(s, "yaw_inertia"), .001)),
          turn(number(s, "view_turn_torque")), yd(number(s, "yaw_damping")),
          angular_inertia(number(s, "impact_angular_inertia")),
          frequency(std::max(number(s, "attitude_stabilization_frequency"), 0.)),
          clearance(number(s, "surface_clearance")), spring(number(s, "boundary_spring_stiffness")),
          damping(number(s, "boundary_spring_damping")), maximum(number(s, "maximum_altitude_ratio")) {}
};
Basis navigation(const Ship &s) { return Basis(s.forward.cross(s.up).normalized(), s.up, -s.forward); }
double surface(Ref<TriangleMesh> mesh, Vector3 up, double scale) {
    if (mesh.is_null())
        return 0;
    Dictionary hit = mesh->intersect_ray(Vector3(), up.normalized());
    if (hit.is_empty()) {
        Vector3 ref = std::abs(up.y) < .9 ? Vector3(0, 1, 0) : Vector3(1, 0, 0);
        hit = mesh->intersect_ray(Vector3(), (up + up.cross(ref).normalized() * .00001).normalized());
    }
    return hit.is_empty() ? 0 : Vector3(hit["position"]).length() * scale;
}
Vector3 predicted(Vector3 p, Vector3 tangent, double ts, double rs, double t) {
    double r = p.length(), future = std::max(r + rs * t, .001), angle = ts * t / std::max(r, .001);
    if (std::abs(rs) > .001)
        angle = ts / rs * std::log(future / std::max(r, .001));
    return (p.normalized() * std::cos(angle) + tangent * std::sin(angle)) * future;
}
Vector3 intercept(Vector3 origin, Vector3 p, Vector3 tangent, double ts, double rs, double speed) {
    double low = 0, high = 0;
    while (high < 8) {
        high = std::min(high + .125, 8.);
        if (origin.distance_to(predicted(p, tangent, ts, rs, high)) <= 1.5 + speed * high) {
            for (int i = 0; i < 18; ++i) {
                double mid = (low + high) * .5;
                if (origin.distance_to(predicted(p, tangent, ts, rs, mid)) > 1.5 + speed * mid)
                    low = mid;
                else
                    high = mid;
            }
            return (predicted(p, tangent, ts, rs, high) - origin).normalized();
        }
        low = high;
    }
    return (p - origin).normalized();
}
void integrate(Ship &s, const Settings &cfg, double delta, Vector2 horizontal, double vertical, double radius,
               Ref<TriangleMesh> terrain, double terrain_scale, bool repulsion) {
    horizontal = horizontal.limit_length();
    vertical = clamp(vertical, -1, 1);
    double remaining = std::min(std::max(delta, 0.), .25);
    while (remaining > .000001) {
        double dt = std::min(remaining, 1. / 120.);
        remaining -= dt;
        double error = std::atan2(s.forward.cross(s.view).dot(s.up), s.forward.dot(s.view));
        double torque = cfg.turn * error - cfg.yd * s.yaw;
        s.yaw += torque / cfg.inertia * dt;
        s.forward = s.forward.rotated(s.up, s.yaw * dt).normalized();
        Quaternion rotation = s.rotation;
        if (rotation.w < 0)
            rotation = -rotation;
        Vector3 imaginary(rotation.x, rotation.y, rotation.z);
        double sine = imaginary.length(), angle = 2 * std::atan2(sine, rotation.w);
        Vector3 attitude_error = sine > .000001 ? imaginary * (angle / sine) : Vector3();
        Vector3 angular_acceleration =
            -attitude_error * (cfg.frequency * cfg.frequency) - s.spin * (2 * cfg.frequency);
        s.spin += angular_acceleration * dt;
        double angular_speed = s.spin.length();
        if (angular_speed < .00001 && angle < .00001) {
            s.rotation = Quaternion();
            s.spin = Vector3();
        } else if (angular_speed > .000001) {
            s.rotation = (Quaternion(s.spin / angular_speed, angular_speed * dt) * s.rotation).normalized();
            if (s.rotation.w < 0)
                s.rotation = -s.rotation;
        }
        double rs = s.velocity.dot(s.up);
        Vector3 tangent = s.velocity - s.up * rs;
        tangent *= std::exp(-std::max(cfg.hd, 0.) * dt);
        rs *= std::exp(-std::max(cfg.vd, 0.) * dt);
        Basis body = navigation(s) * Basis(s.rotation);
        Vector3 acceleration = (body.get_column(0) * horizontal.x - body.get_column(2) * horizontal.y) *
                                   (cfg.horizontal / cfg.mass) +
                               body.get_column(1) * (vertical * cfg.vertical / cfg.mass);
        double force = 0;
        if (repulsion && terrain.is_valid()) {
            double penetration =
                surface(terrain, s.up, terrain_scale) + cfg.clearance - (radius + s.altitude);
            if (penetration > 0)
                force += std::max(0., cfg.spring * penetration - cfg.damping * rs);
        }
        double ceiling = s.altitude - radius * cfg.maximum;
        if (ceiling > 0)
            force -= std::max(0., cfg.spring * ceiling + cfg.damping * rs);
        acceleration += s.up * (force / cfg.mass);
        s.velocity = tangent + s.up * rs + acceleration * dt;
        s.altitude += s.velocity.dot(s.up) * dt;
        tangent = s.velocity - s.up * s.velocity.dot(s.up);
        if (tangent.length_squared() > .000001) {
            Vector3 axis = s.up.cross(tangent.normalized()).normalized();
            double travel = tangent.length() * dt / std::max(radius + s.altitude, .001);
            s.up = s.up.rotated(axis, travel).normalized();
            s.forward = s.forward.rotated(axis, travel).normalized();
            s.view = s.view.rotated(axis, travel).normalized();
            s.velocity = s.velocity.rotated(axis, travel);
        }
    }
    s.forward -= s.up * s.forward.dot(s.up);
    if (s.forward.length_squared() < .000001) {
        Vector3 ref = std::abs(s.up.y) < .99 ? Vector3(0, 1, 0) : Vector3(1, 0, 0);
        s.forward = ref - s.up * ref.dot(s.up);
    }
    s.forward.normalize();
    s.pos = s.up * (radius + s.altitude);
    s.node->set("_local_up", s.up);
    s.node->set("_local_forward", s.forward);
    s.node->set("_local_view_forward", s.view);
    s.node->set("_velocity", s.velocity);
    s.node->set("_altitude", s.altitude);
    s.node->set("_yaw_velocity", s.yaw);
    s.node->set("_impact_rotation", s.rotation);
    s.node->set("_impact_angular_velocity", s.spin);
    Node3D *planet = Object::cast_to<Node3D>(object(s.node, "_planet"));
    s.node->set_global_transform(
        Transform3D(planet->get_global_basis().orthonormalized() * navigation(s) * Basis(s.rotation),
                    planet->to_global(s.up * (1 + s.altitude / radius))));
}
} // namespace
class SunburnSimulation : public RefCounted {
    GDCLASS(SunburnSimulation, RefCounted)
    std::vector<Ship> fleet;
    std::unordered_map<Object *, int> indices;
    std::unordered_map<Cell, std::vector<int>, Hash> spacing;
    struct History {
        struct Sample {
            Vector3 value;
            double duration;
        };
        std::deque<Sample> samples;
        Vector3 integral;
        double duration = 0;
        void add(Vector3 velocity, double dt) {
            if (dt <= 0)
                return;
            if (dt >= 1) {
                samples.clear();
                samples.push_back({velocity, 1});
                duration = 1;
                integral = velocity;
                return;
            }
            samples.push_back({velocity, dt});
            duration += dt;
            integral += velocity * dt;
            double excess = duration - 1;
            while (excess > 0 && !samples.empty()) {
                auto &sample = samples.front();
                double removed = std::min(excess, sample.duration);
                integral -= sample.value * removed;
                duration -= removed;
                sample.duration -= removed;
                excess -= removed;
                if (sample.duration <= 0)
                    samples.pop_front();
            }
        }
        Vector3 average() const { return duration > 0 ? integral / duration : Vector3(); }
    };
    std::unordered_map<Object *, History> histories;
    Node3D *battle = nullptr, *player = nullptr, *planet = nullptr;
    Vector3 player_pos;
    Ref<TriangleMesh> terrain;
    double radius = 0, terrain_scale = 0, ai_speed = 0, separation = 0;
    Ref<RandomNumberGenerator> rng;
    Vector3 target_position(Object *target) {
        if (target == player)
            return player_pos;
        auto it = indices.find(target);
        return it == indices.end() ? Object::cast_to<Node3D>(target)->get_position() : fleet[it->second].pos;
    }
    void update_spacing(Ship &s) {
        Object *target = object(s.node, "target");
        double preferred = radius + number(s.node, "cruise_altitude");
        if (target) {
            double tr = target_position(target).length();
            preferred = preferred * .3 + (tr + number(s.node, "target_altitude_offset")) * .7;
            double reach = std::max(0., number(battle, "firing_range") * .5);
            preferred = clamp(preferred, tr - reach, tr + reach);
        }
        Object *settings = object(s.node, "movement_settings");
        double floor = radius + number(settings, "surface_clearance") + 5;
        if (terrain.is_valid())
            floor = surface(terrain, s.up, terrain_scale) + number(settings, "surface_clearance") + 5;
        s.desired = clamp(preferred, floor,
                          std::max(floor, radius * (1 + number(settings, "maximum_altitude_ratio")) - 5));
        s.separation = Vector3();
        s.pressure = 0;
        if (separation > 0) {
            Cell key = cell(s.previous, separation);
            Vector3 push;
            double pressure = 0;
            for (int x = -1; x <= 1; ++x)
                for (int y = -1; y <= 1; ++y)
                    for (int z = -1; z <= 1; ++z) {
                        auto it = spacing.find({key.x + x, key.y + y, key.z + z});
                        if (it == spacing.end())
                            continue;
                        for (int index : it->second) {
                            Ship &other = fleet[index];
                            if (other.node == s.node)
                                continue;
                            Vector3 away = s.previous - other.previous;
                            double distance = away.length();
                            if (distance >= separation)
                                continue;
                            if (distance < .0001) {
                                int a = s.node->get_index(), b = other.node->get_index();
                                double pair = std::min(a, b) * 173 + std::max(a, b) * 31;
                                away = Vector3(std::sin(pair + 1), std::cos(pair + 2), std::sin(pair + 3))
                                           .normalized() *
                                       (a < b ? -1 : 1);
                            }
                            double weight = std::pow(1 - distance / separation, 2);
                            push += away.normalized() * weight;
                            pressure += weight;
                        }
                    }
            s.separation = limited(push) * std::max(number(battle, "separation_speed"), 0.);
            s.pressure = clamp(pressure, 0, 1);
        }
        s.node->set("desired_orbit_radius", s.desired);
        s.node->set("separation_velocity", s.separation);
        s.node->set("separation_priority", s.pressure);
    }
    void choose(Ship &s) {
        s.node->set("fire_reaction_remaining", -1.);
        std::vector<Object *> candidates;
        std::vector<double> weights;
        double total = 0;
        for (Ship &other : fleet)
            if (other.node != s.node && flag(other.node, "can_fight")) {
                double weight = object(other.node, "target") == s.node ? 3 : 1;
                candidates.push_back(other.node);
                weights.push_back(weight);
                total += weight;
            }
        if (flag(battle, "allow_player_targeting") && object(player, "bound_planet") == planet &&
            flag(player, "can_fight")) {
            candidates.push_back(player);
            weights.push_back(10);
            total += 10;
        }
        Object *target = nullptr;
        if (!candidates.empty()) {
            double roll = rng->randf() * total;
            target = candidates.back();
            for (size_t i = 0; i < candidates.size(); ++i) {
                roll -= weights[i];
                if (roll < 0) {
                    target = candidates[i];
                    break;
                }
            }
        }
        s.node->set("target", target);
        s.node->set("target_remaining", rng->randf_range(number(battle, "target_duration_min"),
                                                         number(battle, "target_duration_max")));
        double spread = number(battle, "target_altitude_spread");
        s.node->set("target_altitude_offset", rng->randf_range(-spread, spread));
        update_spacing(s);
    }
    void missiles(double dt) {
        Node3D *container = battle->get_node<Node3D>("Missiles");
        if (!container->get_child_count())
            return;
        std::vector<Vector3> previous, current;
        std::vector<Node3D *> targets;
        std::unordered_map<Object *, int> launcher_indices;
        for (Ship &s : fleet)
            if (flag(s.node, "can_fight")) {
                launcher_indices[s.node] = targets.size();
                targets.push_back(s.node);
                previous.push_back(s.previous);
                current.push_back(s.pos);
            }
        if (object(player, "bound_planet") == planet && flag(player, "can_fight")) {
            targets.push_back(player);
            previous.push_back(vector(battle, "_player_previous"));
            current.push_back(player_pos);
        }
        double hit_radius = number(battle, "ship_hit_radius"), r2 = hit_radius * hit_radius;
        std::unordered_map<Cell, std::vector<int>, Hash> grid;
        Vector3 padding(hit_radius, hit_radius, hit_radius);
        for (size_t i = 0; i < targets.size(); ++i) {
            Cell first = cell(previous[i].min(current[i]) - padding, 32),
                 last = cell(previous[i].max(current[i]) + padding, 32);
            for (int x = first.x; x <= last.x; ++x)
                for (int y = first.y; y <= last.y; ++y)
                    for (int z = first.z; z <= last.z; ++z)
                        grid[{x, y, z}].push_back(i);
        }
        std::vector<int> visited(targets.size(), -1);
        int query_id = 0;
        Transform3D frame = battle->get_global_transform(), inverse = frame.affine_inverse();
        PhysicsDirectSpaceState3D *space = battle->get_world_3d()->get_direct_space_state();
        TypedArray<Node> children = container->get_children();
        Node3D *explosions = battle->get_node<Node3D>("Explosions");
        for (int m = 0; m < children.size(); ++m) {
            Node3D *missile = Object::cast_to<Node3D>(children[m]);
            Vector3 start = missile->get_position(), velocity = vector(missile, "velocity"),
                    end = start + velocity * dt, motion = end - start;
            Object *launcher = object(missile, "launcher");
            auto excluded_it = launcher_indices.find(launcher);
            int excluded = excluded_it == launcher_indices.end() ? -1 : excluded_it->second;
            double hit_t = INFINITY;
            int hit_index = -1;
            ++query_id;
            Cell first = cell(start.min(end), 32), last = cell(start.max(end), 32);
            for (int x = first.x; x <= last.x && hit_t > 0; ++x)
                for (int y = first.y; y <= last.y && hit_t > 0; ++y)
                    for (int z = first.z; z <= last.z && hit_t > 0; ++z) {
                        auto it = grid.find({x, y, z});
                        if (it == grid.end())
                            continue;
                        for (int i : it->second) {
                            if (i == excluded || visited[i] == query_id)
                                continue;
                            visited[i] = query_id;
                            Vector3 relative = start - previous[i];
                            double c = relative.length_squared() - r2;
                            if (c <= 0) {
                                hit_t = 0;
                                hit_index = i;
                                break;
                            }
                            Vector3 relative_motion = motion - (current[i] - previous[i]);
                            double a = relative_motion.length_squared();
                            if (a <= .000001)
                                continue;
                            double b = relative.dot(relative_motion), disc = b * b - a * c;
                            if (disc >= 0) {
                                double t = (-b - std::sqrt(disc)) / a;
                                if (t >= 0 && t <= 1 && t < hit_t) {
                                    hit_t = t;
                                    hit_index = i;
                                }
                            }
                        }
                    }
            Ref<PhysicsRayQueryParameters3D> ray =
                PhysicsRayQueryParameters3D::create(frame.xform(start), frame.xform(end));
            Dictionary ground = space->intersect_ray(ray);
            if (!ground.is_empty()) {
                double ground_t = start.distance_to(inverse.xform(Vector3(ground["position"]))) /
                                  std::max(double(start.distance_to(end)), .001);
                if (ground_t < hit_t) {
                    hit_t = ground_t;
                    hit_index = -1;
                }
            }
            Vector3 explosion_position;
            bool explode = false;
            if (hit_t <= 1) {
                Vector3 contact = start.lerp(end, hit_t);
                if (hit_index >= 0 && flag(battle, "damage_enabled")) {
                    Node3D *target = targets[hit_index];
                    Vector3 direction = frame.basis.xform(velocity.normalized()),
                            impact = direction * number(battle, "missile_impact_impulse"),
                            center = previous[hit_index].lerp(current[hit_index], hit_t),
                            lever = frame.basis.xform(contact - center);
                    bool was_alive = flag(target, "can_fight");
                    target->call("receive_missile_hit", impact,
                                 lever.cross(direction) * number(battle, "missile_torque_impulse"));
                    if (target != player && was_alive && !flag(target, "can_fight"))
                        battle->call("_refresh_ship_counter");
                    if (target == player) {
                        battle->emit_signal("player_hit");
                        UtilityFunctions::print("Player ship hit by missile from ", launcher->get("name"));
                    }
                }
                explosion_position = contact;
                explode = true;
            } else {
                missile->set_position(end);
                double life = number(missile, "remaining") - dt;
                missile->set("remaining", life);
                if (life <= 0) {
                    explosion_position = end;
                    explode = true;
                }
            }
            if (explode) {
                Node3D *explosion = Object::cast_to<Node3D>(battle->call("_native_make_explosion"));
                explosions->add_child(explosion);
                explosion->set_position(explosion_position);
                missile->call("free");
            }
        }
    }

  protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("reset"), &SunburnSimulation::reset);
        ClassDB::bind_method(D_METHOD("step_missiles", "battle", "delta"), &SunburnSimulation::step_missiles);
        ClassDB::bind_method(D_METHOD("step", "battle", "delta"), &SunburnSimulation::step);
        ClassDB::bind_method(D_METHOD("intercept_direction", "origin", "position", "tangent", "tangent_speed",
                                      "radial_speed", "missile_speed"),
                             &SunburnSimulation::intercept_direction);
    }

  public:
    void step_missiles(Node3D *manager, double dt) {
        battle = manager;
        planet = Object::cast_to<Node3D>(object(battle, "planet"));
        player = Object::cast_to<Node3D>(object(battle, "player"));
        player_pos = vector(battle, "_player_position");
        Array nodes = battle->get("ships");
        fleet.resize(nodes.size());
        for (int i = 0; i < nodes.size(); ++i) {
            fleet[i].node = Object::cast_to<Node3D>(nodes[i]);
            fleet[i].pos = fleet[i].node->get_position();
            fleet[i].previous = vector(fleet[i].node, "previous_position");
        }
        missiles(dt);
    }
    void reset() {
        histories.clear();
        fleet.clear();
        spacing.clear();
        indices.clear();
        terrain.unref();
    }
    Vector3 intercept_direction(Vector3 origin, Vector3 p, Vector3 tangent, double ts, double rs,
                                double speed) {
        return intercept(origin, p, tangent, ts, rs, speed);
    }
    void step(Node3D *manager, double delta) {
        battle = manager;
        planet = Object::cast_to<Node3D>(object(battle, "planet"));
        player = Object::cast_to<Node3D>(object(battle, "player"));
        if (!planet || !player)
            return;
        Transform3D frame(planet->get_global_basis().orthonormalized(), planet->get_global_position());
        battle->set_global_transform(frame);
        player_pos = frame.affine_inverse().xform(player->get_global_position());
        battle->set("_player_position", player_pos);
        radius = planet->get_global_basis().get_column(0).length();
        ai_speed = number(battle, "ai_speed");
        separation = number(battle, "separation_distance");
        rng = Ref<RandomNumberGenerator>(Object::cast_to<RandomNumberGenerator>(object(battle, "_rng")));
        Array history_nodes;
        Array history_ships = battle->get("ships");
        for (int i = 0; i < history_ships.size(); ++i)
            history_nodes.append(history_ships[i]);
        history_nodes.append(player);
        for (int i = 0; i < history_nodes.size(); ++i) {
            Object *node = history_nodes[i];
            if (!flag(node, "can_fight"))
                continue;
            Vector3 up = frame.affine_inverse()
                             .xform(Object::cast_to<Node3D>(node)->get_global_position())
                             .normalized();
            Vector3 velocity = vector(node, "_velocity");
            double radial = velocity.dot(up);
            histories[node].add(Vector3((velocity - up * radial).length(), radial, 0), delta);
        }
        delta = std::min(delta, .1);
        battle->call("_advance_weapon_overheat", delta);
        Array nodes = battle->get("ships");
        fleet.resize(nodes.size());
        indices.clear();
        spacing.clear();
        terrain.unref();
        terrain_scale = radius;
        for (int i = 0; i < nodes.size(); ++i) {
            Ship &s = fleet[i];
            s.node = Object::cast_to<Node3D>(nodes[i]);
            s.pos = s.previous = s.node->get_position();
            s.node->set("previous_position", s.previous);
            s.alive = flag(s.node, "can_fight");
            indices[s.node] = i;
            s.up = vector(s.node, "_local_up");
            s.forward = vector(s.node, "_local_forward");
            s.view = vector(s.node, "_local_view_forward");
            s.velocity = vector(s.node, "_velocity");
            s.spin = vector(s.node, "_impact_angular_velocity");
            s.rotation = s.node->get("_impact_rotation");
            s.altitude = number(s.node, "_altitude");
            s.yaw = number(s.node, "_yaw_velocity");
            s.desired = number(s.node, "desired_orbit_radius");
            s.separation = vector(s.node, "separation_velocity");
            s.pressure = number(s.node, "separation_priority");
            if (s.alive && separation > 0)
                spacing[cell(s.previous, separation)].push_back(i);
            if (terrain.is_null()) {
                Node3D *collider = Object::cast_to<Node3D>(object(s.node, "_surface_collider"));
                if (collider) {
                    terrain = collider->get("_triangles");
                    terrain_scale = collider->get_global_basis().get_column(0).length();
                }
            }
        }
        Camera3D *camera = battle->get_viewport()->get_camera_3d();
        for (Ship &s : fleet) {
            if (flag(s.node, "is_dying")) {
                s.node->call("step_wreck", delta);
                continue;
            }
            if (!s.alive)
                continue;
            double reload = number(s.node, "reload_remaining") - delta;
            s.node->set("reload_remaining", reload);
            double target_time = number(s.node, "target_remaining") - delta;
            s.node->set("target_remaining", target_time);
            Object *target = object(s.node, "target");
            if (target_time <= 0 || !target || !flag(target, "can_fight")) {
                choose(s);
                target = object(s.node, "target");
            }
            double think = number(s.node, "think_remaining") - delta;
            if (think <= 0) {
                think += .1;
                update_spacing(s);
            }
            s.node->set("think_remaining", think);
            Vector3 aim = s.forward, movement = s.forward;
            if (target) {
                aim = target_position(target) - s.pos;
                Vector3 tangent_aim = aim - s.up * aim.dot(s.up),
                        tangent_velocity = s.velocity - s.up * s.velocity.dot(s.up),
                        anticipated = tangent_aim - tangent_velocity * .5;
                double gap = std::abs(s.desired - target_position(target).length()),
                       minimum = number(battle, "minimum_target_distance"),
                       orbit = std::sqrt(std::max(minimum * minimum - gap * gap, 0.)) + 10,
                       closing = clamp((anticipated.length() - orbit) / 10, -1, 1);
                Vector3 circling = s.up.cross(tangent_aim).normalized();
                if (circling.length_squared() < .0001)
                    circling = s.forward;
                Vector3 tangent =
                    tangent_aim.normalized() * closing + circling * std::sqrt(1 - closing * closing);
                double climb = clamp(
                    (s.desired - s.pos.length()) / std::max(number(battle, "altitude_response_seconds"), .05),
                    -number(battle, "altitude_maximum_speed"), number(battle, "altitude_maximum_speed"));
                movement = (tangent * ai_speed + s.up * climb).lerp(s.separation, s.pressure) /
                           std::max(ai_speed, .001);
            }
            Vector3 projected = aim - s.up * aim.dot(s.up);
            if (projected.length_squared() > .000001)
                s.view = projected.normalized();
            Settings cfg(object(s.node, "movement_settings"));
            Vector3 desired = movement * ai_speed;
            double dr = clamp(desired.dot(s.up), -ai_speed, ai_speed), rs = s.velocity.dot(s.up);
            Vector3 tv = s.velocity - s.up * rs,
                    dtangent = limited(desired - s.up * desired.dot(s.up), ai_speed);
            double response = std::max(number(s.node, "velocity_response_seconds"), .05);
            Vector3 acceleration =
                (dtangent - tv) / response + tv * cfg.hd + s.up * ((dr - rs) / response + rs * cfg.vd);
            Basis body = navigation(s) * Basis(s.rotation);
            Vector2 horizontal(
                acceleration.dot(body.get_column(0)) * cfg.mass / std::max(cfg.horizontal, .001),
                -acceleration.dot(body.get_column(2)) * cfg.mass / std::max(cfg.horizontal, .001));
            double vertical = acceleration.dot(body.get_column(1)) * cfg.mass / std::max(cfg.vertical, .001);
            integrate(s, cfg, delta, horizontal, vertical, radius, terrain, terrain_scale,
                      flag(s.node, "surface_repulsion_enabled"));
            bool can_fire = reload <= 0 && target &&
                            (target != player ||
                             (camera && camera->is_position_in_frustum(s.node->get_global_position()))) &&
                            (target_position(target) - s.pos).length() <= number(battle, "firing_range");
            double reaction = number(s.node, "fire_reaction_remaining");
            bool fire = false;
            if (!can_fire)
                reaction = -1;
            else if (reaction < 0)
                reaction = rng->randf_range(number(battle, "fire_reaction_min"),
                                            number(battle, "fire_reaction_max"));
            else {
                reaction -= delta;
                fire = reaction <= 0;
            }
            s.node->set("fire_reaction_remaining", reaction);
            if (fire) {
                Vector3 p = target_position(target), up = p.normalized(),
                        velocity = vector(target, "_velocity"),
                        tangent = (velocity - up * velocity.dot(up)).normalized(),
                        speeds = histories[target].average();
                Vector3 direction = intercept(s.pos, p, tangent, tangent.length_squared() > 0 ? speeds.x : 0,
                                              speeds.y, number(battle, "missile_speed"));
                battle->call("_fire", s.node, direction);
            }
        }
        missiles(delta);
        battle->set("_player_previous", player_pos);
    }
};
void initialize(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE)
        ClassDB::register_class<SunburnSimulation>();
}
extern "C" GDExtensionBool GDE_EXPORT sunburn_sim_init(GDExtensionInterfaceGetProcAddress get_proc,
                                                       GDExtensionClassLibraryPtr library,
                                                       GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc, library, initialization);
    init.register_initializer(initialize);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
