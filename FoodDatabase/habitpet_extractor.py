#!/usr/bin/env python3
"""
HabitPet Nutrient Database Extractor

Extracts foods from SR Legacy JSON based on whitelist and creates a clean
500-item nutrient database for HabitPet.
"""

import json
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from rapidfuzz import fuzz, process

# Nutrient IDs in SR Legacy format
NUTRIENT_IDS = {
    'calories': '208',  # Energy (kcal)
    'protein': '203',   # Protein
    'carbs': '205',    # Carbohydrate, by difference
    'fat': '204'       # Total lipid (fat)
}

# Category mapping function
def map_category(description: str, whitelist_item: str) -> str:
    """Map food description to simplified category."""
    desc_lower = description.lower()
    item_lower = whitelist_item.lower()
    
    # Protein categories
    if any(x in item_lower for x in ['chicken', 'turkey', 'poultry']):
        return "Protein - Poultry"
    if any(x in item_lower for x in ['beef', 'pork', 'meat', 'steak', 'brisket', 'ribeye', 'sirloin', 
                                      'sausage', 'bacon', 'ham', 'pepperoni', 'salami', 'hot dog', 
                                      'bratwurst', 'jerky', 'gyro', 'shawarma', 'meatloaf', 'lasagna']):
        return "Protein - Meat"
    if any(x in item_lower for x in ['salmon', 'tuna', 'shrimp', 'fish', 'cod', 'tilapia', 
                                      'sardines', 'mackerel', 'sushi', 'poke', 'clam', 'crab', 
                                      'mussels', 'calamari', 'tempura']):
        return "Protein - Seafood"
    if any(x in item_lower for x in ['tofu', 'tempeh', 'lentils', 'chickpeas', 'hummus', 'falafel', 
                                      'edamame', 'beans', 'impossible', 'beyond', 'vegan', 'veggie burger', 
                                      'seitan', 'soy']):
        return "Protein - Plant-Based"
    if any(x in item_lower for x in ['egg', 'omelette', 'scrambled']):
        return "Protein - Eggs"
    
    # Grains & Starches
    if any(x in item_lower for x in ['rice', 'quinoa', 'couscous', 'farro', 'barley', 'oatmeal', 
                                      'oats', 'granola', 'pasta', 'spaghetti', 'penne', 'fettuccine', 
                                      'macaroni', 'lasagna', 'ravioli', 'gnocchi', 'noodles', 'ramen', 
                                      'soba', 'udon', 'tortillas', 'pita', 'naan', 'bagel', 'bread', 
                                      'roll', 'sourdough']):
        return "Grains & Starches"
    
    # Vegetables
    if any(x in item_lower for x in ['broccoli', 'cauliflower', 'carrots', 'celery', 'spinach', 
                                      'kale', 'lettuce', 'greens', 'peppers', 'tomatoes', 'cucumbers', 
                                      'avocado', 'onions', 'potatoes', 'sweet potatoes', 'zucchini', 
                                      'squash', 'mushrooms', 'eggplant', 'cabbage', 'brussels', 'kimchi', 
                                      'sauerkraut', 'beans', 'peas', 'corn', 'asparagus', 'bok choy', 
                                      'pickles', 'jalapeno', 'salsa', 'guacamole', 'coleslaw', 
                                      'artichokes', 'seaweed', 'beets', 'radish', 'pumpkin', 'turnips']):
        return "Vegetables"
    
    # Fruits
    if any(x in item_lower for x in ['apple', 'banana', 'orange', 'mandarin', 'grapes', 'strawberries', 
                                      'blueberries', 'raspberries', 'blackberries', 'mango', 'pineapple', 
                                      'watermelon', 'cantaloupe', 'honeydew', 'kiwi', 'peaches', 'plums', 
                                      'nectarines', 'pomegranate', 'pears', 'cherries', 'guava', 'papaya', 
                                      'passion fruit', 'cranberries', 'raisins', 'dates', 'figs', 
                                      'lemon', 'lime', 'grapefruit']):
        return "Fruits"
    
    # Dairy
    if any(x in item_lower for x in ['milk', 'cream', 'yogurt', 'cheese', 'cottage', 'butter', 
                                      'margarine', 'ice cream', 'frozen yogurt', 'ricotta', 'parmesan', 
                                      'feta', 'goat cheese', 'kefir', 'whipped cream']):
        return "Dairy & Alternatives"
    
    # Breakfast
    if any(x in item_lower for x in ['pancakes', 'waffles', 'french toast', 'breakfast', 'hash browns', 
                                      'chia pudding', 'cereal']):
        return "Breakfast"
    
    # Sandwiches & Wraps
    if any(x in item_lower for x in ['sandwich', 'wrap', 'burrito', 'quesadilla', 'tacos', 'pita']):
        return "Sandwiches & Wraps"
    
    # Frozen & Ready Meals
    if any(x in item_lower for x in ['frozen', 'microwave', 'bento', 'tv dinner', 'heat and eat']):
        return "Frozen & Ready Meals"
    
    # Snacks
    if any(x in item_lower for x in ['chips', 'crackers', 'pretzels', 'popcorn', 'nuts', 'almonds', 
                                      'walnuts', 'cashews', 'pistachios', 'peanut butter', 'almond butter', 
                                      'rice cakes', 'jerky', 'fruit snacks', 'chocolate', 'cookies', 
                                      'brownies', 'muffins', 'banana bread', 'protein bar', 'granola bar', 
                                      'trail mix', 'edamame snack', 'seaweed snacks', 'veggie straws']):
        return "Snacks"
    
    # Drinks
    if any(x in item_lower for x in ['water', 'soda', 'coffee', 'tea', 'latte', 'cappuccino', 
                                      'lemonade', 'smoothie', 'shake', 'sports drink', 'energy drink', 
                                      'juice', 'kombucha', 'milkshake', 'chai', 'matcha']):
        return "Drinks"
    
    # Desserts
    if any(x in item_lower for x in ['cake', 'cupcakes', 'donuts', 'pie', 'pudding', 'sorbet', 
                                      'cheesecake', 'tiramisu', 'mochi', 'churros', 'cinnamon rolls', 
                                      'banana split']):
        return "Desserts"
    
    # Salads
    if any(x in item_lower for x in ['salad', 'caesar', 'greek', 'garden', 'cobb', 'quinoa salad', 
                                      'lentil salad', 'pasta salad', 'fruit salad']):
        return "Salads"
    
    # International
    if any(x in item_lower for x in ['pad thai', 'pho', 'ramen', 'bibimbap', 'tikka', 'masala', 
                                      'biryani', 'curry', 'gyro', 'shawarma', 'falafel', 'poke bowl', 
                                      'teriyaki', 'katsu', 'spring rolls', 'dumplings', 'gyoza', 
                                      'poutine', 'empanada', 'tamales', 'enchiladas', 'arepas']):
        return "International & Ethnic"
    
    # Pizza
    if 'pizza' in item_lower:
        return "Pizza"
    
    # Default
    return "Other"


def normalize_text(text: str) -> str:
    """Normalize text for matching."""
    return re.sub(r'[^\w\s]', ' ', text.lower()).strip()


def extract_nutrients(food_item: Dict) -> Dict[str, Optional[float]]:
    """Extract macronutrients from food item."""
    nutrients = {
        'calories': None,
        'protein': None,
        'carbs': None,
        'fat': None
    }
    
    food_nutrients = food_item.get('foodNutrients', [])
    
    for nutrient in food_nutrients:
        nutrient_obj = nutrient.get('nutrient', {})
        nutrient_number = nutrient_obj.get('number', '')
        amount = nutrient.get('amount')
        
        if nutrient_number == NUTRIENT_IDS['calories']:
            nutrients['calories'] = amount
        elif nutrient_number == NUTRIENT_IDS['protein']:
            nutrients['protein'] = amount
        elif nutrient_number == NUTRIENT_IDS['carbs']:
            nutrients['carbs'] = amount
        elif nutrient_number == NUTRIENT_IDS['fat']:
            nutrients['fat'] = amount
    
    return nutrients


def match_whitelist_item(description: str, whitelist: List[str]) -> Optional[Tuple[str, float]]:
    """
    Match description against whitelist using multiple strategies.
    Returns (matched_item, score) or None.
    """
    desc_normalized = normalize_text(description)
    
    # Strategy 1: Exact match
    for item in whitelist:
        if desc_normalized == normalize_text(item):
            return (item, 100.0)
    
    # Strategy 2: Starts with
    for item in whitelist:
        item_normalized = normalize_text(item)
        if desc_normalized.startswith(item_normalized) or item_normalized.startswith(desc_normalized):
            return (item, 95.0)
    
    # Strategy 3: Contains
    for item in whitelist:
        item_normalized = normalize_text(item)
        if item_normalized in desc_normalized or desc_normalized in item_normalized:
            # Prefer longer matches
            score = min(len(item_normalized) / len(desc_normalized) * 90, 90.0)
            return (item, score)
    
    # Strategy 4: Fuzzy matching with rapidfuzz (try multiple scorers)
    best_match = None
    best_score = 0
    
    # Try token_set_ratio first (most lenient)
    match1 = process.extractOne(
        desc_normalized,
        whitelist,
        scorer=fuzz.token_set_ratio,
        score_cutoff=60
    )
    if match1 and match1[1] > best_score:
        best_match = match1
        best_score = match1[1]
    
    # Try partial_ratio for partial matches
    match2 = process.extractOne(
        desc_normalized,
        whitelist,
        scorer=fuzz.partial_ratio,
        score_cutoff=60
    )
    if match2 and match2[1] > best_score:
        best_match = match2
        best_score = match2[1]
    
    # Try token_sort_ratio for word order variations
    match3 = process.extractOne(
        desc_normalized,
        whitelist,
        scorer=fuzz.token_sort_ratio,
        score_cutoff=60
    )
    if match3 and match3[1] > best_score:
        best_match = match3
        best_score = match3[1]
    
    if best_match:
        return (best_match[0], best_match[1])
    
    return None


def main():
    print("=" * 60)
    print("HabitPet Nutrient Database Extractor")
    print("=" * 60)
    
    # Paths
    script_dir = Path(__file__).parent
    sr_legacy_path = Path("/Users/janicec/Downloads/FoodData_Central_sr_legacy_food_json_2018-04.json")
    whitelist_path = script_dir / "habitpet_whitelist.txt"
    output_path = script_dir / "habitpet_local_foods.json"
    missing_path = script_dir / "missing_matches.txt"
    
    # Load whitelist
    print(f"\n[1/4] Loading whitelist from {whitelist_path}...")
    with open(whitelist_path, 'r') as f:
        whitelist = [line.strip().lower() for line in f if line.strip()]
    print(f"   Loaded {len(whitelist)} whitelist items")
    
    # Load SR Legacy JSON
    print(f"\n[2/4] Loading SR Legacy JSON from {sr_legacy_path}...")
    print("   (This may take a minute for ~210MB file)...")
    with open(sr_legacy_path, 'r', encoding='utf-8') as f:
        sr_legacy_wrapper = json.load(f)
        # Extract the array from the wrapper object
        sr_legacy_data = sr_legacy_wrapper.get('SRLegacyFoods', sr_legacy_wrapper)
        if not isinstance(sr_legacy_data, list):
            # If it's not a list, try to get the first value (might be the array)
            sr_legacy_data = list(sr_legacy_wrapper.values())[0] if sr_legacy_wrapper else []
    print(f"   Loaded {len(sr_legacy_data)} foods from SR Legacy")
    
    # Match and extract
    print(f"\n[3/4] Matching whitelist items against SR Legacy database...")
    # Store best match for each whitelist item
    whitelist_matches = {}  # whitelist_item -> (food_item, score, description)
    
    for idx, food_item in enumerate(sr_legacy_data):
        if (idx + 1) % 10000 == 0:
            print(f"   Processed {idx + 1:,} foods, found {len(whitelist_matches)} matches so far...")
        
        description = food_item.get('description', '')
        match_result = match_whitelist_item(description, whitelist)
        
        if match_result:
            matched_item, score = match_result
            
            # Extract nutrients
            nutrients = extract_nutrients(food_item)
            
            # Skip if missing critical nutrients
            if nutrients['calories'] is None:
                continue
            
            # Store best match for this whitelist item (higher score wins)
            if matched_item not in whitelist_matches or score > whitelist_matches[matched_item][1]:
                whitelist_matches[matched_item] = (food_item, score, description)
    
    # Convert matches to output format
    print(f"\n   Converting {len(whitelist_matches)} matches to output format...")
    matched_foods = []
    for matched_item, (food_item, score, description) in whitelist_matches.items():
        # Extract nutrients
        nutrients = extract_nutrients(food_item)
        
        # Map category
        category = map_category(description, matched_item)
        
        # Create output item
        output_item = {
            "name": description,
            "fdcId": food_item.get('fdcId'),
            "category": category,
            "calories": nutrients['calories'],
            "protein": nutrients['protein'],
            "carbs": nutrients['carbs'],
            "fat": nutrients['fat']
        }
        
        matched_foods.append(output_item)
        
        # Progress update every 25 matches
        if len(matched_foods) % 25 == 0:
            print(f"   ✓ Processed {len(matched_foods)} foods (latest: {description[:50]}...)")
    
    missing_items = [item for item in whitelist if item not in whitelist_matches]
    
    # Find missing items
    print(f"\n[4/4] Checking for missing matches...")
    
    # Save output
    print(f"\n[5/5] Saving results...")
    with open(output_path, 'w') as f:
        json.dump(matched_foods, f, indent=2)
    
    # Save missing items
    with open(missing_path, 'w') as f:
        for item in missing_items:
            f.write(f"{item}\n")
    
    # Summary
    print("\n" + "=" * 60)
    print("EXTRACTION COMPLETE")
    print("=" * 60)
    print(f"Total foods matched:     {len(matched_foods)}")
    print(f"Missing matches:         {len(missing_items)}")
    print(f"Output file:             {output_path}")
    print(f"Output file size:        {output_path.stat().st_size / 1024:.1f} KB")
    print(f"Missing items log:       {missing_path}")
    
    if missing_items:
        print(f"\nFirst 10 missing items:")
        for item in missing_items[:10]:
            print(f"  - {item}")
    
    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()

