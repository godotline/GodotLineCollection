with open('d:/Code/GODOTLINE/GodotLineCollection/Scripts/LevelManager.gd', 'r', encoding='utf-8') as f:
    content = f.read()

print(f"Original length: {len(content)}")

# 1. Replace all _view_toggle_btn -> view_toggle_btn
count = content.count('_view_toggle_btn')
content = content.replace('_view_toggle_btn', 'view_toggle_btn')
print(f"Replaced {count} occurrences of _view_toggle_btn")

# 2. Remove _create_view_toggle method (entire function)
# Find the function boundaries
start_marker = '\nfunc _create_view_toggle() -> void:'
end_marker = '\nfunc _on_view_toggle_pressed() -> void:'

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx >= 0 and end_idx > start_idx:
    before = content[:start_idx]
    after = content[end_idx + 1:]  # +1 to keep the newline
    content = before + '\n' + after.lstrip('\n')
    print(f"Removed _create_view_toggle (indices {start_idx} to {end_idx})")
else:
    print(f"FAILED to find method boundaries: start={start_idx}, end={end_idx}")

print(f"New length: {len(content)}")

with open('d:/Code/GODOTLINE/GodotLineCollection/Scripts/LevelManager.gd', 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
