#!/usr/bin/env python3
import requests
import json

def show_profile():
    # Search for a deep stack trace profile
    response = requests.get("http://localhost:9200/java-profiles/_search", headers={"Content-Type": "application/json"}, json={
        "query": {
            "bool": {
                "must": [
                    {"exists": {"field": "java_packages"}},
                    {"range": {"stack_depth": {"gte": 30}}}
                ]
            }
        },
        "size": 1
    })

    data = response.json()
    if not data['hits']['hits']:
        print("No enhanced profiles with deep stacks found")
        return

    hit = data['hits']['hits'][0]
    src = hit['_source']

    print("=" * 70)
    print("DETAILED JAVA PROFILE WITH STACK TRACE")
    print("=" * 70)
    print(f"Timestamp:     {src.get('@timestamp')}")
    print(f"Service:       {src.get('service')}")
    print(f"Profiler:      {src.get('profiler')} v{src.get('profiler_version', 'N/A')}")
    print(f"Stack Depth:   {src.get('stack_depth')} frames")
    print(f"Sample Count:  {src.get('sample_count')}")
    print(f"Profile Type:  {src.get('profile_type', 'collapsed')}")
    print()

    if 'frame_types' in src:
        print("Frame Types:")
        for ftype, count in src['frame_types'].items():
            print(f"  - {ftype}: {count}")
    print()

    if 'java_packages' in src:
        print(f"Java Packages ({len(src['java_packages'])}):")
        for pkg in src['java_packages'][:10]:
            print(f"  - {pkg}")
        if len(src['java_packages']) > 10:
            print(f"  ... and {len(src['java_packages']) - 10} more")
    print()

    if 'java_classes' in src:
        print(f"Java Classes ({len(src['java_classes'])}):")
        for cls in src['java_classes'][:10]:
            print(f"  - {cls}")
        if len(src['java_classes']) > 10:
            print(f"  ... and {len(src['java_classes']) - 10} more")
    print()

    print("STACK TRACE:")
    print("-" * 70)
    for i, frame in enumerate(src.get('stack', [])[:30]):
        name = frame.get('name', 'unknown')
        type_mark = '[KERNEL]' if frame.get('is_kernel') else '[JAVA]  '

        print(f"{i+1:3}. {type_mark} {name}")

        if frame.get('method'):
            pkg = frame.get('package', '')
            cls = frame.get('class', '')
            method = frame.get('method', '')
            print(f"         → {pkg}.{cls}.{method}()")

    if len(src.get('stack', [])) > 30:
        print(f"... and {len(src['stack']) - 30} more frames")

    print()
    print("=" * 70)

if __name__ == "__main__":
    show_profile()
