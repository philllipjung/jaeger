#!/usr/bin/env python3
"""
Export eBPF Profiling Data from OTEL Collector JSON files to OpenSearch

This script:
1. Monitors a directory for profile JSON files from OTEL Collector
2. Parses the profile data (which uses indices and lookup tables)
3. Creates one OpenSearch document per profile sample
4. Indexes them into OpenSearch for analysis and visualization

Usage:
    python export_profiles_to_opensearch.py [--watch]
"""

import json
import os
import sys
import time
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional
import logging

try:
    from opensearchpy import OpenSearch, RequestsHttpConnection
except ImportError:
    print("Installing opensearch-py...")
    os.system(f"{sys.executable} -m pip install opensearch-py")
    from opensearchpy import OpenSearch, RequestsHttpConnection

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# OpenSearch configuration
OPENSEARCH_HOST = 'localhost'
OPENSEARCH_PORT = 9200
OPENSEARCH_INDEX = 'ebpf-profiles'
OPENSEARCH_USER = None
OPENSEARCH_PASSWORD = None


class ProfileProcessor:
    """Process eBPF profile data and export to OpenSearch"""

    def __init__(self, opensearch_client: OpenSearch, index_name: str):
        self.client = opensearch_client
        self.index_name = index_name
        self._ensure_index_template()

    def _ensure_index_template(self):
        """Create OpenSearch index template with proper mappings"""
        template = {
            "index_patterns": [f"{self.index_name}*"],
            "template": {
                "settings": {
                    "number_of_shards": 1,
                    "number_of_replicas": 0,
                    "index.mapping.nested_fields.limit": 100
                },
                "mappings": {
                    "properties": {
                        "@timestamp": {"type": "date"},
                        "process": {
                            "properties": {
                                "pid": {"type": "integer"},
                                "name": {"type": "keyword"}
                            }
                        },
                        "thread": {
                            "properties": {
                                "id": {"type": "integer"},
                                "name": {"type": "keyword"}
                            }
                        },
                        "sample": {
                            "properties": {
                                "count": {"type": "integer"},
                                "period": {"type": "long"},
                                "period_unit": {"type": "keyword"}
                            }
                        },
                        "function": {
                            "properties": {
                                "name": {"type": "keyword"},
                                "filename": {"type": "text"},
                                "address": {"type": "keyword"}
                            }
                        },
                        "frame_type": {"type": "keyword"},
                        "timestamp_unix_nano": {"type": "long"},
                        "duration_nanos": {"type": "long"},
                        "resource": {
                            "properties": {
                                "container_id": {"type": "keyword"},
                                "host_name": {"type": "keyword"}
                            }
                        },
                        "scope": {
                            "properties": {
                                "name": {"type": "keyword"},
                                "version": {"type": "keyword"}
                            }
                        }
                    }
                }
            }
        }

        try:
            self.client.indices.put_index_template(
                name=f"{self.index_name}-template",
                body=template
            )
            logger.info(f"Created index template for {self.index_name}")
        except Exception as e:
            logger.warning(f"Failed to create index template: {e}")

    def resolve_attribute(self, attr_index: int, attribute_table: List[Dict]) -> Dict[str, Any]:
        """Resolve attribute from attribute table using index"""
        if 0 <= attr_index < len(attribute_table):
            attr = attribute_table[attr_index]
            key = attr.get('key', '')
            value = attr.get('value', {})

            # Extract the actual value based on type
            if 'stringValue' in value:
                return {key: value['stringValue']}
            elif 'intValue' in value:
                return {key: value['intValue']}
            elif 'doubleValue' in value:
                return {key: value['doubleValue']}
            elif 'boolValue' in value:
                return {key: value['boolValue']}
        return {}

    def resolve_function_name(self, func_index: int, string_table: List[str],
                             function_table: List[Dict]) -> Dict[str, str]:
        """Resolve function name and filename from tables"""
        if func_index >= len(function_table):
            return {"name": "unknown", "filename": "unknown"}

        func = function_table[func_index]
        name_str_index = func.get('nameStrindex', 0)
        filename_str_index = func.get('filenameStrindex', -1)

        function_name = string_table[name_str_index] if name_str_index < len(string_table) else "unknown"
        filename = string_table[filename_str_index] if 0 <= filename_str_index < len(string_table) else "unknown"

        return {
            "name": function_name,
            "filename": filename
        }

    def resolve_location(self, loc_index: int, location_table: List[Dict],
                        string_table: List[str], function_table: List[Dict],
                        attribute_table: List[Dict]) -> Dict[str, Any]:
        """Resolve a single location (stack frame) from the location table"""
        if loc_index >= len(location_table):
            return {}

        location = location_table[loc_index]
        address = location.get('address', 'unknown')
        lines = location.get('line', [])

        # Get the function name for this location
        frame_info = {
            "address": address,
            "frames": []
        }

        for line_info in lines:
            func_index = line_info.get('functionIndex', 0)
            func_info = self.resolve_function_name(func_index, string_table, function_table)
            func_info['address'] = address
            frame_info["frames"].append(func_info)

        # Resolve attributes for this location
        attr_indices = location.get('attributeIndices', [])
        for attr_idx in attr_indices:
            attr = self.resolve_attribute(attr_idx, attribute_table)
            frame_info.update(attr)

        return frame_info

    def resolve_samples(self, sample_indices: List[int], location_indices: List[int],
                       locations_start: int, locations_length: int,
                       location_table: List[Dict], string_table: List[str],
                       function_table: List[Dict], attribute_table: List[Dict]) -> List[Dict]:
        """Resolve sample indices to actual stack frames"""
        frames = []

        for i in range(locations_length):
            sample_idx = locations_start + i
            if sample_idx < len(sample_indices):
                loc_index = sample_indices[sample_idx]
                frame = self.resolve_location(
                    loc_index, location_table, string_table,
                    function_table, attribute_table
                )
                if frame:
                    frames.append(frame)

        return frames

    def process_profile_data(self, profile_data: Dict) -> List[Dict[str, Any]]:
        """Process profile data and create flat documents for OpenSearch"""
        documents = []

        try:
            resource_profiles = profile_data.get('resourceProfiles', [])
            dictionary = profile_data.get('dictionary', {})
            string_table = dictionary.get('stringTable', [])
            location_table = dictionary.get('locationTable', [])
            function_table = dictionary.get('functionTable', [])
            attribute_table = dictionary.get('attributeTable', [])

            for resource_profile in resource_profiles:
                resource = resource_profile.get('resource', {})
                resource_attrs = {attr['key']: attr.get('value', {}).get('stringValue', '')
                                 for attr in resource.get('attributes', [])}

                scope_profiles = resource_profile.get('scopeProfiles', [])

                for scope_profile in scope_profiles:
                    scope = scope_profile.get('scope', {})
                    profiles = scope_profile.get('profiles', [])

                    for profile in profiles:
                        sample_type = profile.get('sampleType', [])
                        period_type = profile.get('periodType', {})
                        period = profile.get('period', 0)
                        duration_nanos = profile.get('durationNanos', '0')
                        time_nanos = profile.get('timeNanos', '0')

                        # Convert nanoseconds to seconds
                        timestamp_sec = int(time_nanos) / 1_000_000_000 if time_nanos else time.time()

                        samples = profile.get('sample', [])
                        location_indices = profile.get('locationIndices', [])

                        for sample in samples:
                            locations_start = sample.get('locationsStartIndex', 0)
                            locations_length = sample.get('locationsLength', 0)
                            values = sample.get('value', [])
                            attribute_indices = sample.get('attributeIndices', [])
                            timestamps = sample.get('timestampsUnixNano', [])

                            # Resolve sample attributes (thread info, process info)
                            sample_attributes = {}
                            for attr_idx in attribute_indices:
                                attr = self.resolve_attribute(attr_idx, attribute_table)
                                sample_attributes.update(attr)

                            # Resolve stack frames for this sample
                            stack_frames = self.resolve_samples(
                                location_indices, location_indices,
                                locations_start, locations_length,
                                location_table, string_table,
                                function_table, attribute_table
                            )

                            # Determine frame type (kernel/user)
                            frame_type = "unknown"
                            for frame in stack_frames:
                                if frame.get('profile.frame.type') == 'kernel':
                                    frame_type = 'kernel'
                                    break
                            if frame_type == 'unknown':
                                frame_type = 'user'

                            # Extract top function for easy querying
                            top_function = {}
                            if stack_frames and stack_frames[0].get('frames'):
                                top_function = stack_frames[0]['frames'][0]

                            # Create OpenSearch document
                            doc = {
                                "@timestamp": datetime.fromtimestamp(timestamp_sec).isoformat(),
                                "timestamp_unix_nano": int(time_nanos) if time_nanos else 0,
                                "duration_nanos": int(duration_nanos) if duration_nanos else 0,
                                "sample": {
                                    "count": int(values[0]) if values else 1,
                                    "period": int(period) if period else 0,
                                    "period_unit": string_table[period_type.get('unitStrindex', 2)] if period_type.get('unitStrindex', 2) < len(string_table) else 'nanoseconds'
                                },
                                "frame_type": frame_type,
                                "stack_frames": stack_frames,
                                "top_function": top_function,
                                "resource": resource_attrs,
                                "scope": {
                                    "name": scope.get('name', ''),
                                    "version": scope.get('version', '')
                                }
                            }

                            # Add sample attributes
                            doc['process'] = {
                                "pid": sample_attributes.get('process.pid', 0),
                                "name": sample_attributes.get('process.executable.name',
                                          sample_attributes.get('thread.name', 'unknown'))
                            }
                            doc['thread'] = {
                                "id": sample_attributes.get('thread.id', 0),
                                "name": sample_attributes.get('thread.name', 'unknown')
                            }

                            documents.append(doc)

        except Exception as e:
            logger.error(f"Error processing profile data: {e}", exc_info=True)

        return documents

    def export_to_opensearch(self, documents: List[Dict]) -> int:
        """Export documents to OpenSearch in bulk"""
        if not documents:
            return 0

        bulk_data = []
        for doc in documents:
            # Index metadata
            bulk_data.append(json.dumps({
                "index": {
                    "_index": self.index_name,
                    "_id": f"{doc.get('timestamp_unix_nano', '')}_{doc.get('thread', {}).get('id', '')}"
                }
            }))
            # Document
            bulk_data.append(json.dumps(doc, default=str))

        bulk_body = "\n".join(bulk_data) + "\n"

        try:
            response = self.client.bulk(body=bulk_body)
            errors = response.get('errors', False)

            if errors:
                logger.warning(f"Bulk export had some errors: {response}")
            else:
                logger.info(f"Successfully exported {len(documents)} profile documents to OpenSearch")

            return len(documents)

        except Exception as e:
            logger.error(f"Error exporting to OpenSearch: {e}", exc_info=True)
            return 0


def process_json_file(file_path: str, processor: ProfileProcessor) -> bool:
    """Process a single JSON profile file"""
    try:
        with open(file_path, 'r') as f:
            profile_data = json.load(f)

        logger.info(f"Processing profile file: {file_path}")
        documents = processor.process_profile_data(profile_data)

        if documents:
            count = processor.export_to_opensearch(documents)
            logger.info(f"Exported {count} documents from {file_path}")
            return True
        else:
            logger.warning(f"No documents extracted from {file_path}")
            return False

    except Exception as e:
        logger.error(f"Error processing file {file_path}: {e}", exc_info=True)
        return False


def watch_directory(directory: str, processor: ProfileProcessor, interval: int = 10):
    """Watch directory for new profile files and process them"""
    processed_files = set()

    logger.info(f"Watching directory: {directory} (interval: {interval}s)")

    while True:
        try:
            for file_path in Path(directory).glob("*.json"):
                if file_path.name not in processed_files:
                    success = process_json_file(str(file_path), processor)
                    if success:
                        processed_files.add(file_path.name)
                        # Optionally move processed file
                        # file_path.rename(Path(directory) / "processed" / file_path.name)

            time.sleep(interval)

        except KeyboardInterrupt:
            logger.info("Stopping directory watch...")
            break
        except Exception as e:
            logger.error(f"Error in watch loop: {e}", exc_info=True)
            time.sleep(interval)


def main():
    parser = argparse.ArgumentParser(
        description='Export eBPF profiles from OTEL Collector to OpenSearch'
    )
    parser.add_argument(
        '--directory',
        default='/root/jaeger/docker-compose/monitor/profiles',
        help='Directory containing profile JSON files'
    )
    parser.add_argument(
        '--watch',
        action='store_true',
        help='Continuously watch directory for new files'
    )
    parser.add_argument(
        '--opensearch-host',
        default=OPENSEARCH_HOST,
        help='OpenSearch host'
    )
    parser.add_argument(
        '--opensearch-port',
        type=int,
        default=OPENSEARCH_PORT,
        help='OpenSearch port'
    )
    parser.add_argument(
        '--index',
        default=OPENSEARCH_INDEX,
        help='OpenSearch index name'
    )
    parser.add_argument(
        '--interval',
        type=int,
        default=10,
        help='Watch interval in seconds (default: 10)'
    )

    args = parser.parse_args()

    # Initialize OpenSearch client
    client = OpenSearch(
        hosts=[{'host': args.opensearch_host, 'port': args.opensearch_port}],
        http_auth=(OPENSEARCH_USER, OPENSEARCH_PASSWORD) if OPENSEARCH_USER else None,
        use_http=(not OPENSEARCH_USER),
        verify_certs=False,
        ssl_show_warn=False,
        connection_class=RequestsHttpConnection
    )

    # Test connection
    try:
        info = client.info()
        logger.info(f"Connected to OpenSearch: {info['version']['number']}")
    except Exception as e:
        logger.error(f"Failed to connect to OpenSearch: {e}")
        sys.exit(1)

    # Create processor
    processor = ProfileProcessor(client, args.index)

    if args.watch:
        # Watch mode: continuously process new files
        watch_directory(args.directory, processor, args.interval)
    else:
        # One-shot mode: process existing files
        for file_path in Path(args.directory).glob("*.json"):
            process_json_file(str(file_path), processor)


if __name__ == '__main__':
    main()
