// SPDX-FileCopyrightText: 2024 Diego Elio Pettenò
//
// SPDX-License-Identifier: 0BSD

// Blister-related parameters.
// These are the ones you want to change to match your
// blister configuration!
blister_length = 92.5;
blister_width = 55;

pill_diameter = 13;

// How many pills lengthwise
pills_rows = 5;
// How many pills widthwise.
pills_columns = 3;

// Only makes sense if rows and colums are odd!
center_pill = false;

// This assumes equal spacing between pills in rows and columns.
pills_spacing = 3.5;

// Design parameters.
// Only change these if you want to experiment with the design,
// or if somehow it doesn't work for you.
plate_height = 2;

base_wall = 9;

buster_length = 7;

alignment_pin_diameter = 4;
alignment_pin_length = 30;

// Post-processed parameters. Don't change these, they are formulaic.
plate_length = blister_length + base_wall * 2;
plate_width = blister_width + base_wall * 2;

base_height = 
    alignment_pin_length
    - buster_length - plate_height /* The buster itself */
    - plate_height  /* The upper grid */
    - 3 /* The blister spacing */
    ;
    
plate_size = [plate_width, plate_length, plate_height];

pills_col_middle = pills_columns % 2;
pills_col_side = pills_columns / 2 - (pills_col_middle ? 0.5 : 0);

pills_row_middle = pills_rows % 2;
pills_row_side = pills_rows / 2 - (pills_row_middle ? 0.5 : 0);

horizontal_directions = pills_row_middle ? [-1, 0, 1] : [-1, 1];
vertical_directions = pills_col_middle ? [-1, 0, 1] : [-1, 1];

function get_all_pills_coords() = [
    for (
        pill_row = [1:pills_row_side],
        horizontal_direction = horizontal_directions,
        pill_column = [1:pills_col_side],
        vertical_direction = vertical_directions
    )
        [pill_row * horizontal_direction, pill_column * vertical_direction]
];
    
function get_all_pills_coords_maybe_center() = [
    for(coords=get_all_pills_coords())
        if (coords != [0, 0] || center_pill)
            coords
];

    
function get_pill_distance_odd(pill_idx) =
    pill_idx == 0 ? 0 :
        (pill_diameter + pills_spacing) * pill_idx;

function get_pill_distance_even(pill_idx) =
    pill_idx == 0 ? -11111111111111 :
        (pills_spacing /2 + pill_diameter / 2) +
        (pill_diameter + pills_spacing) * (pill_idx - 1);
    
function get_pill_center(coords) = 
    [
        pills_col_middle ? get_pill_distance_odd(coords[1]) :
            get_pill_distance_even(coords[0]),
        pills_row_middle ? get_pill_distance_odd(coords[0]) :
            get_pill_distance_even(coords[1]),
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
    0, 0, base_height + 10 + plate_height + buster_length
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
            
            translate([base_wall, base_wall]) {
                cube([
                    plate_width - base_wall * 2,
                    plate_length - base_wall * 2,
                    base_height - plate_height
                ]);
            }
            
            translate([0, 0, base_height - plate_height]) {
                for (pill_idxs = get_all_pills_coords()) {
                    translate(
                        get_pill_center(pill_idxs) - plate_origin_coordinates
                    ) {
                        cube(
                            [pill_diameter, pill_diameter, plate_height * 3],
                            center=true
                        );
                    }
                }                
            }
            
            // Carve holes for the alignment pins. They don't go
            // all the way to the bottom of the base!
            translate([0, 0, plate_height]) {
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
                [pill_diameter/2, pill_diameter/2]
            ) {
                cube([pill_diameter, pill_diameter, base_height]);
            }
        }        
    }
}



// Top Grid, center pill open even if present.
translate(top_grid_origin) {
    difference() {
        cube(plate_size, center=true);
        
        for (pill_idxs = get_all_pills_coords()) {
            translate(get_pill_center(pill_idxs)) {
                cube([pill_diameter, pill_diameter, 4], center=true);
            }
        }

        // Alignment Holes
        for(pin=alignment_pins_coords) {
            translate(pin) {
                cylinder(
                    plate_height * 1.1,
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
            translate([0, 0, buster_length + plate_height / 2]) {
                cube(plate_size, center=true);
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
        translate([0, 0, buster_length]) {
            for(pin=alignment_pins_coords) {
                translate(pin + [0, 0, buster_length]) {
                    cylinder(
                        plate_height * 1.1  ,
                        alignment_pin_hole_radius,
                        alignment_pin_hole_radius,
                        $fn=720
                    );
                }
            }
        }
    } 
}
