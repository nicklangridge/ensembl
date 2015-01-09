-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

# patch_77_78_b.sql
#
# Title: Increase source column size
#
# Description:
#   RefSeq data requires more characters in the gene and transcript source column.

ALTER TABLE gene MODIFY COLUMN source VARCHAR(40) NOT NULL;
ALTER TABLE transcript MODIFY COLUMN source VARCHAR(40) NOT NULL default 'ensembl';

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_77_78_b.sql|source_column_increase');
