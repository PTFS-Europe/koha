-- 
-- Default classification sources and filing rules
-- for Koha.
--
-- Copyright (C) 2007 LiblimeA
--
-- This file is part of Koha.
--
-- Koha is free software; you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation; either version 2 of the License, or (at your option) any later
-- version.
-- 
-- Koha is distributed in the hope that it will be useful, but WITHOUT ANY
-- WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
-- A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License along
-- with Koha; if not, write to the Free Software Foundation, Inc.,
-- 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

-- class sorting (filing) rules
INSERT INTO `class_sort_rules` (`class_sort_rule`, `description`, `sort_routine`) VALUES
                               ('dewey', 'Default filing rules for DDC', 'Dewey'),
                               ('lcc', 'Default filing rules for LCC', 'LCC'),
                               ('generic', 'Generic call number filing rules', 'Generic');

-- splitting rules
INSERT INTO `class_split_rules` (`class_split_rule`, `description`, `split_routine`) VALUES
                               ('dewey', 'Default splitting rules for DDC', 'Dewey'),
                               ('lcc', 'Default splitting rules for LCC', 'LCC'),
                               ('generic', 'Generic call number splitting rules', 'Generic');

-- classification schemes or sources
INSERT INTO `class_sources` (`cn_source`, `description`, `used`, `class_sort_rule`, `class_split_rule`) VALUES
                            ('ddc', 'Dewey Decimal Classification', 1, 'dewey', 'dewey'),
                            ('lcc', 'Library of Congress Classification', 1, 'lcc', 'lcc'),
                            ('udc', 'Universal Decimal Classification', 0, 'generic', 'generic'),
                            ('sudocs', 'SuDoc Classification (U.S. GPO)', 0, 'generic', 'generic'),
                            ('anscr', 'ANSCR (Sound Recordings)', 0, 'generic', 'generic'),
                            ('z', 'Other/Generic Classification Scheme', 0, 'generic', 'generic');
