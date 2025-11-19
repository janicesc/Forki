#!/usr/bin/env python3
"""
HabitPet USDA Category Assigner

Assigns USDA categories from CSV lookup tables to FNDDS foods,
then merges all food databases into a master list.
"""

import json
import csv
from pathlib import Path
from collections import Counter

print("=" * 60)
print("HabitPet USDA Category Assigner")
print("=" * 60)

script_dir = Path(__file__).parent

# ------------------------------------------------------------
# 1. LOAD INPUT FILES
# ------------------------------------------------------------
print("\n[1/6] Loading input files...")

# JSON files
local_foods_path = script_dir / "habitpet_local_foods.json"
fndds_added_path = script_dir / "habitpet_fndds_added_foods.json"
fndds_manual_path = script_dir / "habitpet_fndds_manual_additions.json"

print(f"   Loading {local_foods_path.name}...")
with open(local_foods_path, 'r') as f:
    local_foods = json.load(f)
print(f"   Loaded {len(local_foods)} items")

print(f"   Loading {fndds_added_path.name}...")
with open(fndds_added_path, 'r') as f:
    fndds_added = json.load(f)
print(f"   Loaded {len(fndds_added)} items")

print(f"   Loading {fndds_manual_path.name}...")
with open(fndds_manual_path, 'r') as f:
    fndds_manual = json.load(f)
print(f"   Loaded {len(fndds_manual)} items")

# CSV files (for SR Legacy foods)
food_csv_path = Path("/Users/janicec/Downloads/FoodData_Central_sr_legacy_food_csv_2018-04/food.csv")
food_category_csv_path = Path("/Users/janicec/Downloads/FoodData_Central_sr_legacy_food_csv_2018-04/food_category.csv")

print(f"   Loading {food_csv_path.name}...")
with open(food_csv_path, 'r', encoding='utf-8') as f:
    food_reader = csv.DictReader(f)
    food_data = list(food_reader)
print(f"   Loaded {len(food_data)} food records")

print(f"   Loading {food_category_csv_path.name}...")
with open(food_category_csv_path, 'r', encoding='utf-8') as f:
    category_reader = csv.DictReader(f)
    category_data = list(category_reader)
print(f"   Loaded {len(category_data)} category records")

# FNDDS JSON file (for FNDDS category lookup)
fndds_json_path = Path("/Users/janicec/Downloads/fndds_2021_2023.json")
print(f"   Loading {fndds_json_path.name} for FNDDS category lookup...")
with open(fndds_json_path, 'r', encoding='utf-8') as f:
    fndds_full = json.load(f)
fndds_foods = fndds_full.get('SurveyFoods', [])
if not fndds_foods:
    if isinstance(fndds_full, list):
        fndds_foods = fndds_full
    else:
        for key, value in fndds_full.items():
            if isinstance(value, list):
                fndds_foods = value
                break
print(f"   Loaded {len(fndds_foods)} FNDDS foods for category lookup")

# ------------------------------------------------------------
# 2. BUILD CATEGORY LOOKUP TABLES
# ------------------------------------------------------------
print("\n[2/6] Building category lookup tables...")

# Build categoryMap: food_category_id -> category_description
categoryMap = {}
for row in category_data:
    cat_id = row.get('id', '').strip()
    cat_desc = row.get('description', '').strip()
    if cat_id and cat_desc:
        categoryMap[cat_id] = cat_desc

print(f"   Built category map with {len(categoryMap)} categories")

# Build categoryByFdcId: fdcId -> food_category_id (for SR Legacy)
categoryByFdcId = {}
for row in food_data:
    fdc_id = row.get('fdc_id', '').strip()
    cat_id = row.get('food_category_id', '').strip()
    if fdc_id and cat_id:
        categoryByFdcId[fdc_id] = cat_id

print(f"   Built FDC ID to category map with {len(categoryByFdcId)} mappings (SR Legacy)")

# Build FNDDS category lookup: fdcId -> wweiaFoodCategoryDescription
fndds_category_by_fdc_id = {}
for food in fndds_foods:
    fdc_id = str(food.get('fdcId', ''))
    wweia_cat = food.get('wweiaFoodCategory', {})
    if isinstance(wweia_cat, dict):
        cat_desc = wweia_cat.get('wweiaFoodCategoryDescription', '').strip()
        if fdc_id and cat_desc:
            fndds_category_by_fdc_id[fdc_id] = cat_desc

print(f"   Built FNDDS category map with {len(fndds_category_by_fdc_id)} mappings")

# ------------------------------------------------------------
# 3. APPLY PRECISE USDA CATEGORY
# ------------------------------------------------------------
print("\n[3/6] Applying USDA categories to FNDDS foods...")

def assign_category(item):
    """Assign USDA category to an item based on its fdcId."""
    fdc_id = str(item.get('fdcId', ''))
    
    # First try FNDDS category (for FNDDS foods)
    if fdc_id in fndds_category_by_fdc_id:
        return fndds_category_by_fdc_id[fdc_id]
    
    # Then try SR Legacy category (for SR Legacy foods)
    if fdc_id in categoryByFdcId:
        food_category_id = categoryByFdcId[fdc_id]
        if food_category_id in categoryMap:
            return categoryMap[food_category_id]
    
    return "Uncategorized"

# Process FNDDS added foods
fndds_added_categorized = []
for item in fndds_added:
    item_copy = item.copy()
    item_copy['category'] = assign_category(item)
    fndds_added_categorized.append(item_copy)

uncategorized_added = sum(1 for item in fndds_added_categorized if item['category'] == 'Uncategorized')
print(f"   Categorized {len(fndds_added_categorized)} FNDDS added foods ({uncategorized_added} uncategorized)")

# Process FNDDS manual additions
fndds_manual_categorized = []
for item in fndds_manual:
    item_copy = item.copy()
    item_copy['category'] = assign_category(item)
    fndds_manual_categorized.append(item_copy)

uncategorized_manual = sum(1 for item in fndds_manual_categorized if item['category'] == 'Uncategorized')
print(f"   Categorized {len(fndds_manual_categorized)} FNDDS manual foods ({uncategorized_manual} uncategorized)")

# ------------------------------------------------------------
# 4. SAVE NEW CATEGORIZED FILES
# ------------------------------------------------------------
print("\n[4/6] Saving categorized files...")

fndds_added_categorized_path = script_dir / "habitpet_fndds_added_foods_categorized.json"
fndds_manual_categorized_path = script_dir / "habitpet_fndds_manual_additions_categorized.json"

with open(fndds_added_categorized_path, 'w') as f:
    json.dump(fndds_added_categorized, f, indent=2)
print(f"   Saved {fndds_added_categorized_path.name}")

with open(fndds_manual_categorized_path, 'w') as f:
    json.dump(fndds_manual_categorized, f, indent=2)
print(f"   Saved {fndds_manual_categorized_path.name}")

# ------------------------------------------------------------
# 5. MERGE ALL FOODS INTO FINAL MASTER LIST
# ------------------------------------------------------------
print("\n[5/6] Merging all foods into master list...")

# Combine all foods
all_foods = []
all_foods.extend(local_foods)
all_foods.extend(fndds_added_categorized)
all_foods.extend(fndds_manual_categorized)

print(f"   Combined {len(all_foods)} total items before deduplication")

# Remove duplicates using searchKey as unique key
# For items without searchKey, use name as fallback
seen_keys = {}
master_foods = []

for item in all_foods:
    # Get unique key (prefer searchKey, fallback to normalized name)
    unique_key = item.get('searchKey', '').strip().lower()
    if not unique_key:
        unique_key = item.get('name', '').strip().lower()
    
    if unique_key and unique_key not in seen_keys:
        seen_keys[unique_key] = True
        master_foods.append(item)
    elif not unique_key:
        # If no key at all, add it anyway (shouldn't happen)
        master_foods.append(item)

print(f"   After deduplication: {len(master_foods)} unique items")

# Sort alphabetically by searchKey (or name if no searchKey)
def get_sort_key(item):
    key = item.get('searchKey', '').strip().lower()
    if not key:
        key = item.get('name', '').strip().lower()
    return key

master_foods.sort(key=get_sort_key)

# Save master list
master_path = script_dir / "habitpet_master_foods.json"
with open(master_path, 'w') as f:
    json.dump(master_foods, f, indent=2)
print(f"   Saved {master_path.name} ({master_path.stat().st_size / 1024:.1f} KB)")

# ------------------------------------------------------------
# 6. PRINT SUMMARY
# ------------------------------------------------------------
print("\n[6/6] Generating summary...")

print("\n" + "=" * 60)
print("SUMMARY")
print("=" * 60)

print(f"\nTotal items in master list: {len(master_foods)}")

# Count by category
category_counts = Counter(item.get('category', 'Unknown') for item in master_foods)

print(f"\nItems per category:")
for category, count in sorted(category_counts.items(), key=lambda x: (-x[1], x[0])):
    print(f"   {category}: {count}")

# Count uncategorized
uncategorized_count = category_counts.get('Uncategorized', 0)
if uncategorized_count > 0:
    print(f"\n⚠️  Uncategorized items: {uncategorized_count}")
else:
    print(f"\n✓ All items are categorized")

# Breakdown by source
print(f"\nItems by source:")
local_count = len([item for item in master_foods if item.get('category', '').startswith('Protein') or 
                   item.get('category', '').startswith('Grains') or 
                   item.get('category', '').startswith('Vegetables') or
                   item.get('category', '').startswith('Fruits') or
                   item.get('category', '').startswith('Dairy') or
                   item.get('category', '').startswith('Breakfast') or
                   item.get('category', '').startswith('Snacks') or
                   item.get('category', '').startswith('Drinks') or
                   item.get('category', '').startswith('Desserts') or
                   item.get('category', '').startswith('Salads') or
                   item.get('category', '').startswith('International') or
                   item.get('category', '').startswith('Pizza') or
                   item.get('category', '').startswith('Sandwiches') or
                   item.get('category', '').startswith('Frozen') or
                   item.get('category', '') == 'Other'])

# Better way: check if item has searchKey that matches FNDDS patterns
fndds_added_count = len([item for item in master_foods if 'searchKey' in item and 
                          any(item.get('name', '') in fndds_item.get('name', '') 
                              for fndds_item in fndds_added_categorized)])
fndds_manual_count = len([item for item in master_foods if 'searchKey' in item and 
                           any(item.get('name', '') in fndds_item.get('name', '') 
                               for fndds_item in fndds_manual_categorized)])

print(f"   SR Legacy (local):     {len(local_foods)}")
print(f"   FNDDS auto-added:      {len(fndds_added_categorized)}")
print(f"   FNDDS manual:          {len(fndds_manual_categorized)}")

print("\n" + "=" * 60)
print("COMPLETE")
print("=" * 60)
print(f"\nMaster file saved to: {master_path}")

