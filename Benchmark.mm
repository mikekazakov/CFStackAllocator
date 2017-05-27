#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string>
#include <iostream>
#include <vector>
#include <algorithm>
#include <numeric>
#include <chrono>
#include <array>
#include "CFStackAllocator.h"

using namespace std;
using namespace std::chrono;

template<typename F>
nanoseconds measure_time(F f)
{
    static const auto num_trials = 20;
    static const auto min_time_per_trial = milliseconds{200};
    array<nanoseconds, num_trials> trials;
    volatile static decltype(f()) res;
    
    for( auto &trial: trials) {
        int runs = 0;
        const auto t1 = chrono::high_resolution_clock::now();
        auto t2 = t1;
        for(;
            t2 - t1 < min_time_per_trial;
            ++runs, t2 = chrono::high_resolution_clock::now() )
            res = f();
            cout << res << endl;
        
        trial = duration_cast<nanoseconds>(t2 - t1) / runs;
    }
    
    sort( trials.begin(), trials.end() );
    auto avg = accumulate( trials.begin()+2, trials.end()-2, nanoseconds{0} ) / (trials.size()-4);
    return duration_cast<nanoseconds>(avg);
}

const char *g_Dictionary[] = {
u8"😀", u8"😃", u8"😄", u8"😁", u8"😆", u8"😅", u8"😂", u8"🤣",
u8"☺️", u8"😊", u8"😇", u8"🙂", u8"🙃", u8"😉", u8"😌", u8"😍",
u8"😘", u8"😗", u8"😙", u8"😚", u8"😋", u8"😜", u8"😝", u8"😛",
u8"🤑", u8"🤗", u8"🤓", u8"😎", u8"🤡", u8"🤠", u8"😏", u8"😒",
u8"😞", u8"😔", u8"😟", u8"😕", u8"🙁", u8"☹️", u8"😣", u8"😖",
u8"😫", u8"😩", u8"😤", u8"😠", u8"😡", u8"😶", u8"😐", u8"😑"
};

string NextRandomString( int _min_size, int _max_size )
{
    auto length = _min_size + rand() % (_max_size - _min_size);
    string s;
    while( length --> 0 )
        s += g_Dictionary[ rand() % size(g_Dictionary) ];
    return s;
}

vector<string> BuildSamples( int _amount, int _min_size, int _max_size  )
{
    vector<string> samples( _amount );
    for( auto &s: samples )
        s = NextRandomString( _min_size, _max_size );
    return samples;
}

unsigned long Hash_NSString( const vector<string> &_data )
{
    unsigned long hash = 0;
    @autoreleasepool {
        for( const auto &s: _data ) {
            const auto nsstring = [[NSString alloc] initWithBytes:s.data()
                                                           length:s.length()
                                                         encoding:NSUTF8StringEncoding];
            hash += nsstring.lowercaseString.decomposedStringWithCanonicalMapping.hash;
        }
    }
    return hash;
}

unsigned long Hash_CFString( const vector<string> &_data )
{
    unsigned long hash = 0;
    const auto locale = CFLocaleCopyCurrent();
    
    for( const auto &s: _data ) {
        const auto cfstring =  CFStringCreateWithBytes(0,
                                                       (UInt8*)s.data(),
                                                       s.length(),
                                                       kCFStringEncodingUTF8,
                                                       false);
        const auto cfmstring = CFStringCreateMutableCopy(0, 0, cfstring);
        CFStringLowercase(cfmstring, locale);
        CFStringNormalize(cfmstring, kCFStringNormalizationFormD);
        hash += CFHash(cfmstring);
        
        CFRelease(cfmstring);
        CFRelease(cfstring);
    }
    CFRelease(locale);
    
    return hash;
}

unsigned long Hash_CFString_SA( const vector<string> &_data )
{
    unsigned long hash = 0;
    const auto locale = CFLocaleCopyCurrent();
    
    for( const auto &s: _data ) {
        CFStackAllocator alloc;
        const auto cfstring =  CFStringCreateWithBytes(alloc.Alloc(),
                                                       (UInt8*)s.data(),
                                                       s.length(),
                                                       kCFStringEncodingUTF8,
                                                       false);
        const auto cfmstring = CFStringCreateMutableCopy(alloc.Alloc(), 0, cfstring);
        CFStringLowercase(cfmstring, locale);
        CFStringNormalize(cfmstring, kCFStringNormalizationFormD);
        hash += CFHash(cfmstring);
        
        CFRelease(cfmstring);
        CFRelease(cfstring);
    }
    CFRelease(locale);
    
    return hash;
}

int main(int argc, const char * argv[])
{
    const auto samples_amount = 1'000'000;
    const auto samples_min_length = 50;
    const auto samples_max_length = 100;
    const auto samples = BuildSamples( samples_amount, samples_min_length, samples_max_length );
    
    const auto w1 = [&]{ return Hash_NSString(samples); };
    const auto t1 = measure_time( w1 );
    cout << double(t1.count()) / 1E6  << endl;
    
    const auto w2 = [&]{ return Hash_CFString(samples); };
    const auto t2 = measure_time( w2 );
    cout << double(t2.count()) / 1E6  << endl;
    
    const auto w3 = [&]{ return Hash_CFString_SA(samples); };
    const auto t3 = measure_time( w3 );
    cout << double(t3.count()) / 1E6  << endl;
    
    return 0;
}
