#!/usr/bin/env python3
"""
Optimized RAG Test - Timeout sorunlarını çözen hızlı test scripti
"""

import time
import requests
import json
from concurrent.futures import ThreadPoolExecutor, TimeoutError
import threading

API_BASE_URL = "http://127.0.0.1:8080"
# http://127.0.0.1:8080/docs

# Kısa ve anlaşılır test soruları (timeout riskini azaltmak için)
quick_medical_questions = [
    "What is primary aldosteronism?",
    "What is hypokalemia?", 
    "What causes bilateral hyperplasia?",
    "What are the symptoms of hyperaldosteronism?",
    "What is the prevalence of bilateral hyperplasia?"
]

def test_single_query_with_timeout(question: str, timeout_seconds: int = 120) -> dict:
    """Tek soruyu timeout ile test et"""
    print(f"🔍 Testing: {question}")
    start_time = time.time()
    
    def make_request():
        return requests.post(
            f"{API_BASE_URL}/query",
            headers={"Content-Type": "application/json"},
            json={"question": question},
            timeout=timeout_seconds
        )
    
    try:
        # ThreadPoolExecutor ile timeout kontrolü
        with ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(make_request)
            try:
                response = future.result(timeout=timeout_seconds)
                end_time = time.time()
                response_time = end_time - start_time
                
                if response.status_code == 200:
                    data = response.json()
                    answer = data["answer"]
                    
                    # Kalite kontrolü
                    has_medical_content = any(word in answer.lower() for word in 
                                            ['aldosterone', 'potassium', 'hypertension', 'adrenal', 'hyperplasia'])
                    
                    return {
                        "success": True,
                        "question": question,
                        "answer": answer,
                        "response_time": response_time,
                        "answer_length": len(answer),
                        "has_medical_content": has_medical_content,
                        "status": "✅ SUCCESS"
                    }
                else:
                    return {
                        "success": False,
                        "error": f"HTTP {response.status_code}",
                        "response_time": response_time,
                        "status": "❌ HTTP ERROR"
                    }
                    
            except TimeoutError:
                return {
                    "success": False,
                    "error": f"Timeout after {timeout_seconds} seconds",
                    "response_time": timeout_seconds,
                    "status": "⏰ TIMEOUT"
                }
                
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "response_time": time.time() - start_time,
            "status": "💥 CONNECTION ERROR"
        }

def test_api_availability():
    """API'nin erişilebilir olduğunu kontrol et"""
    try:
        response = requests.get(f"{API_BASE_URL}/", timeout=10)
        return response.status_code == 200
    except:
        return False

def run_optimized_test():
    """Optimize edilmiş RAG testi"""
    print("🚀 OPTIMIZED RAG PERFORMANCE TEST")
    print("=" * 60)
    
    # API Availability Check
    print("🌐 Checking API availability...")
    if not test_api_availability():
        print("❌ API is not available! Please start the server first.")
        return
    
    print("✅ API is available!")
    
    # Health check
    try:
        health_response = requests.get(f"{API_BASE_URL}/health", timeout=10)
        if health_response.status_code == 200:
            health_data = health_response.json()
            print(f"🏥 System Health: API={health_data.get('api', 'Unknown')}, LLM={health_data.get('llm', 'Unknown')}, DB={health_data.get('database', 'Unknown')}")
        else:
            print("⚠️ Health check failed")
    except:
        print("⚠️ Health check unavailable")
    
    print("\n" + "=" * 60)
    print("📋 Starting Medical RAG Tests...")
    print("=" * 60)
    
    results = []
    successful_tests = 0
    timeout_tests = 0
    error_tests = 0
    total_time = 0
    
    for i, question in enumerate(quick_medical_questions, 1):
        print(f"\n📝 Test {i}/{len(quick_medical_questions)}")
        print("-" * 40)
        
        result = test_single_query_with_timeout(question, timeout_seconds=90)
        results.append(result)
        
        # Result display
        print(f"Status: {result['status']}")
        print(f"Response Time: {result['response_time']:.2f}s")
        
        if result["success"]:
            successful_tests += 1
            total_time += result["response_time"]
            print(f"Answer Length: {result['answer_length']} chars")
            print(f"Medical Content: {'✅ Yes' if result.get('has_medical_content', False) else '❌ No'}")
            
            # Preview ilk 1000 karakter
            preview = result['answer'][:1000] + "..." if len(result['answer']) > 100 else result['answer']
            print(f"Preview: {preview}")
            
        else:
            if "timeout" in result["error"].lower():
                timeout_tests += 1
            else:
                error_tests += 1
            print(f"Error: {result['error']}")
        
        # Progress indicator
        progress = (i / len(quick_medical_questions)) * 100
        print(f"Progress: {progress:.1f}%")
        
        print("-" * 40)
    
    # Final Statistics
    print(f"\n🏁 FINAL RESULTS")
    print("=" * 60)
    print(f"📊 Test Summary:")
    print(f"   ✅ Successful: {successful_tests}/{len(quick_medical_questions)}")
    print(f"   ⏰ Timeouts: {timeout_tests}")
    print(f"   💥 Errors: {error_tests}")
    
    if successful_tests > 0:
        avg_time = total_time / successful_tests
        success_rate = (successful_tests / len(quick_medical_questions)) * 100
        
        print(f"\n⚡ Performance Metrics:")
        print(f"   🕐 Average Response Time: {avg_time:.2f} seconds")
        print(f"   📈 Success Rate: {success_rate:.1f}%")
        
        # Performance Rating
        if avg_time < 15:
            speed_rating = "🚀 EXCELLENT"
        elif avg_time < 30:
            speed_rating = "⚡ GOOD"
        elif avg_time < 60:
            speed_rating = "🐌 SLOW"
        else:
            speed_rating = "🔴 VERY SLOW"
        
        if success_rate >= 80:
            reliability_rating = "🛡️ HIGHLY RELIABLE"
        elif success_rate >= 60:
            reliability_rating = "✅ RELIABLE"
        elif success_rate >= 40:
            reliability_rating = "⚠️ MODERATE"
        else:
            reliability_rating = "🔴 UNRELIABLE"
        
        print(f"   🏃 Speed Rating: {speed_rating}")
        print(f"   🎯 Reliability: {reliability_rating}")
        
        # Recommendations
        print(f"\n💡 RECOMMENDATIONS:")
        if avg_time > 30:
            print(f"   • Consider using a smaller LLM model for faster responses")
            print(f"   • Enable GPU acceleration if available")
            print(f"   • Reduce model context size (n_ctx)")
        
        if timeout_tests > 0:
            print(f"   • Increase timeout values for complex queries")
            print(f"   • Monitor system resources (RAM/CPU)")
        
        if successful_tests == len(quick_medical_questions):
            print(f"   🎉 All tests passed! Your RAG system is working well!")
    
    return results

if __name__ == "__main__":
    run_optimized_test()
