#!/bin/bash
# ============================================
# OPENSEARCH SEARCH GUIDE FOR JAVA PROFILES
# ============================================

echo "=========================================="
echo "Java Profiles Search Examples"
echo "=========================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# 1. BASIC COUNTS
# ============================================
echo -e "${BLUE}1. BASIC COUNTS${NC}"
echo "===================="

echo "Total profiles:"
curl -s "localhost:9200/java-profiles/_count" | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin), indent=2))" 2>/dev/null || curl -s "localhost:9200/java-profiles/_count"

echo ""
echo "Count by profile type:"
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "size": 0,
  "aggs": {
    "by_type": {
      "terms": {
        "field": "profile_type.keyword"
      }
    }
  }
}' | grep -A5 "by_type"

echo ""
read -p "Press Enter to continue..."
echo ""

# ============================================
# 2. SEARCH BY SPECIFIC FIELDS
# ============================================
echo -e "${BLUE}2. SEARCH BY SPECIFIC FIELDS${NC}"
echo "================================"

echo "Example: Find all 'flat' profile types:"
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {
    "term": {
      "profile_type.keyword": "flat"
    }
  },
  "size": 2,
  "_source": ["profile_type", "method", "total_samples"]
}' | grep -E "total|profile_type|method" | head -10

echo ""
read -p "Press Enter to continue..."
echo ""

# ============================================
# 3. TIME RANGE QUERIES
# ============================================
echo -e "${BLUE}3. TIME RANGE QUERIES${NC}"
echo "===================="

echo "Profiles from last 5 minutes:"
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {
    "range": {
      "@timestamp": {
        "gte": "now-5m"
      }
    }
  },
  "size": 1,
  "_source": ["@timestamp", "service"]
}' | grep -E "total|@timestamp|service"

echo ""
read -p "Press Enter to continue..."
echo ""

# ============================================
# 4. FULL TEXT SEARCH
# ============================================
echo -e "${BLUE}4. FULL TEXT SEARCH${NC}"
echo "===================="

echo "Search for 'okhttp' in all fields:"
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {
    "multi_match": {
      "query": "okhttp",
      "fields": ["log", "method"]
    }
  },
  "size": 1
}' | head -30

echo ""
read -p "Press Enter to continue..."
echo ""

# ============================================
# 5. AGGREGATIONS (ANALYTICS)
# ============================================
echo -e "${BLUE}5. AGGREGATIONS (ANALYTICS)${NC}"
echo "=============================="

echo "Top 5 methods by sample count:"
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "size": 0,
  "query": {
    "exists": {
      "field": "total_samples"
    }
  },
  "aggs": {
    "top_methods": {
      "terms": {
        "field": "method.keyword",
        "size": 5,
        "order": {
          "total_samples": "desc"
        }
      },
      "aggs": {
        "total_samples": {
          "sum": {
            "field": "total_samples"
          }
        }
      }
    }
  }
}' | grep -A10 "aggregations"

echo ""
read -p "Press Enter to continue..."
echo ""

# ============================================
# 6. COMPLEX QUERIES
# ============================================
echo -e "${BLUE}6. COMPLEX QUERIES${NC}"
echo "=================="

echo "Find profiles with > 5 samples:"
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {
    "range": {
      "total_samples": {
        "gt": 5
      }
    }
  },
  "size": 3,
  "_source": ["method", "total_samples"]
}' | head -40

echo ""

# ============================================
# 7. RAW DATA RETRIEVAL
# ============================================
echo -e "${BLUE}7. RAW DATA RETRIEVAL${NC}"
echo "======================"

echo "Get latest profile with full source:"
curl -s "localhost:9200/java-profiles/_search?pretty" -H "Content-Type: application/json" -d '{
  "query": {"match_all": {}},
  "size": 1,
  "sort": [{"@timestamp": "desc"}]
}' | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'hits' in data and 'hits' in data['hits']:
    hit = data['hits']['hits'][0]
    print('_id:', hit.get('_id'))
    print(json.dumps(hit.get('_source', {}), indent=2))
" 2>/dev/null || echo "Could not format with python"

echo ""
echo "=========================================="
echo "Search Examples Complete!"
echo "=========================================="
