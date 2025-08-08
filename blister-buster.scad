// SPDX-FileCopyrightText: 2024 Diego Elio Pettenò
//
// SPDX-License-Identifier: 0BSD

// Blister-related parameters.
// These are the ones you want to change to match your blister configuration!

// These represent the size of the full blister, not just the part of it with the pills.
// It's okay if the blister is not symmetric, as most of them would have lot information
// on one of the sides.
blister_length = 110;
blister_width = 63.1;

pill_diameter = 12.5;

// How many pills in the two directions, and the outer length of the pills.
// Refer to the blister-diagram image for a reference of which measures
// to take!
pills_rows = 5;
pills_vertical_length = 93.5;

pills_columns = 3;
pills_horizontal_length = 53.1;

// Only makes sense if rows and colums are odd!
center_pill = false;

// Design parameters.
// Only change these if you want to experiment with the design,
// or if somehow it doesn't work for you.

stopper_plate_height = 2;     // Force is exerted on this.
buster_plate_height = 2;      // And on this.
alignment_plate_height = 0.8; // But not on this, this is alignment only.

base_wall = 9;

buster_length = 7;

alignment_pin_diameter = 4;
alignment_pin_length = 30;

// Post-processed parameters. Don't change these, they are formulaic.

plate_length = blister_length + base_wall * 2;
plate_width = blister_width + base_wall * 2;

base_height = 
    alignment_pin_length
    - buster_length - buster_plate_height /* The buster itself */
    - alignment_plate_height              /* The upper grid */
    - 3 /* The blister spacing */
    ;
    
// Oversize the hole a bit to give it a bit more tollerance.
pill_hole_side = pill_diameter * 1.05;
    
pills_col_middle = pills_columns % 2;
pills_col_side = pills_columns / 2 - (pills_col_middle ? 0.5 : 0);
pills_col_spacing = (pills_horizontal_length - (pills_columns * pill_diameter)) / (pills_columns - 1);

pills_row_middle = pills_rows % 2;
pills_row_side = pills_rows / 2 - (pills_row_middle ? 0.5 : 0);
pills_row_spacing = (pills_vertical_length - (pills_rows * pill_diameter)) / (pills_rows - 1);

horizontal_directions = pills_row_middle ? [-1, 0, 1] : [-1, 1];
vertical_directions = pills_col_middle ? [-1, 0, 1] : [-1, 1];

function get_all_pills_coords() = [
    for (
        pill_row = [1:pills_row_side],
        horizontal_direction = horizontal_directions,
        pill_column = [1:pills_col_side],
        vertical_direction = vertical_directions
    )
        [pill_column * vertical_direction, pill_row * horizontal_direction]
];
    
function get_all_pills_coords_maybe_center() = [
    for(coords=get_all_pills_coords())
        if (coords != [0, 0] || center_pill)
            coords
];

    
function get_pill_distance_odd(pill_idx, pills_spacing) =
    pill_idx == 0 ? 0 :
        (pill_diameter + pills_spacing) * pill_idx;

function get_pill_distance_even(pill_idx, pills_spacing) =
    pill_idx == 0 ? -11111111111111 :
        (pills_spacing /2 + pill_diameter / 2) +
        (pill_diameter + pills_spacing) * (pill_idx - 1);
    
function get_pill_center(coords) = 
    [
        pills_col_middle ? get_pill_distance_odd(coords[0], pills_col_spacing) :
            get_pill_distance_even(coords[0], pills_col_spacing),
        pills_row_middle ? get_pill_distance_odd(coords[1], pills_row_spacing) :
            get_pill_distance_even(coords[1], pills_row_spacing),
    ];


// Decisions:
//  - Keep the horizontal center of the device at [0, 0] but build upwards.

plate_origin_coordinates = [
    -plate_width / 2,
    -plate_length / 2,
];

top_grid_origin = [
    0, 0, base_height + 5
];

buster_origin = [
    0, 0, base_height + 4 + alignment_plate_height + buster_length
];

// Add a 10% to account for tolerances.
alignment_pin_hole_radius = alignment_pin_diameter * 0.55;

alignment_pin_in_wall_center = 
    (base_wall - alignment_pin_hole_radius * 2) / 2
    + alignment_pin_hole_radius;

alignment_pins_coords = [
    plate_origin_coordinates +
        [alignment_pin_in_wall_center, alignment_pin_in_wall_center],
    -plate_origin_coordinates -
        [alignment_pin_in_wall_center, alignment_pin_in_wall_center]
];

// The base uses absolute coordinates to make sure the negative space has exactly
// the size it needs. Using relative coordinates to zero makes it harder.
translate (plate_origin_coordinates) {
    // Base of the device, includes the slots for the alignment pins,
    // the optional supports, and the bottom grid.
    union() {
        difference() {
            union() {
                // The main body of the base.
                cube([plate_width, plate_length, base_height]);
            }
            
            // the 0.001 fudge is to avoid the artifact on the bottom during pre-render.
            translate([base_wall, base_wall, -0.001 ]) {
                cube([
                    plate_width - base_wall * 2,
                    plate_length - base_wall * 2,
                    base_height - stopper_plate_height + 0.001
                ]);
            }
            
            translate([0, 0, base_height - stopper_plate_height]) {
                for (pill_idxs = get_all_pills_coords()) {
                    translate(
                        get_pill_center(pill_idxs) - plate_origin_coordinates
                    ) {
                        cube(
                            [pill_hole_side, pill_hole_side, stopper_plate_height * 3],
                            center=true
                        );
                    }
                }                
            }
            
            // Carve holes for the alignment pins. They don't go
            // all the way to the bottom of the base!
            translate([0, 0, stopper_plate_height]) {
                for(pin=alignment_pins_coords) {
                    translate(pin - plate_origin_coordinates) {
                        cylinder(
                            base_height * 50,
                            alignment_pin_hole_radius,
                            alignment_pin_hole_radius,
                            $fn=720
                        );
                    }
                }
            }
        }
        
        // If there is no center pill, we build an additional support
        // in the center.
        if (!center_pill) {
            translate(
                -plate_origin_coordinates -
                [pill_hole_side/2, pill_hole_side/2]
            ) {
                cube([pill_hole_side, pill_hole_side, base_height]);
            }
        }        
    }
}



// Top Grid, center pill open even if present.
translate(top_grid_origin) {
    difference() {
        cube([plate_width, plate_length, alignment_plate_height], center=true);
        
        for (pill_idxs = get_all_pills_coords()) {
            translate(get_pill_center(pill_idxs)) {
                cube([pill_hole_side, pill_hole_side, 4], center=true);
            }
        }

        // Alignment Holes
        for(pin=alignment_pins_coords) {
            translate(pin) {
                cylinder(
                    alignment_plate_height * 1.1,
                    alignment_pin_hole_radius,
                    alignment_pin_hole_radius,
                    center=true,
                    $fn=720
                );
            }
        }
    } 
}


// Actual pill buster
translate(buster_origin) {
    difference() {
        union() {
            translate([0, 0, buster_length + buster_plate_height / 2]) {
                cube([plate_width, plate_length, buster_plate_height], center=true);
            }
            
            for (pill_idxs = get_all_pills_coords_maybe_center()) {
                translate(get_pill_center(pill_idxs)) {
                    cylinder(
                        buster_length,
                        pill_diameter * 0.35,
                        pill_diameter * 0.5,
                        $fn=180
                    );
                }
            }

        }

        // Alignment Holes
        // the 0.001 fudge is to avoid the artifact on the bottom during pre-render.
        translate([0, 0, buster_length - 0.001]) {
            for(pin=alignment_pins_coords) {
                translate(pin + [0, 0, buster_length]) {
                    cylinder(
                        buster_plate_height * 1.1  ,
                        alignment_pin_hole_radius,
                        alignment_pin_hole_radius,
                        $fn=720
                    );
                }
            }
        }
    } 
}
