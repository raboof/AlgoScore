# Copyright 2007, 2008, Jonatan Liljedahl
#
# This file is part of AlgoScore.
#
# AlgoScore is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# AlgoScore is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with AlgoScore.  If not, see <http://www.gnu.org/licenses/>.

import("mathx","*");
var round = func(x) { int(x+0.5); }
var max = func(x,y) { x>y?x:y; }
var min = func(x,y) { x<y?x:y; }
var clip = func(x,a,b) {
    if(x>b) return b;
    if(x<a) return a;
    return x;
}
var mirror = func(x,a,b) {
    while(1) {
        if(x<a) x=a*2-x;
        elsif(x>b) x=b*2-x;
        else return x;
    }
}
var floor = func(x) { int(x); }

var quant = func(x,q,s=1) {
    var x2 = x-(mod(x,q));
    return s==1?x2:x2-(x2-x)*(1-s);
}

var linrand = func {
    var a=rand();
    var b=rand();
    if(b<a) a=b;
    return a;
}

var trirand = func(mode=nil) {
    var a=rand();
    if(mode==nil) {
        var b=rand();
        return 0.5*(a+b);
    } else {
        return (a <= mode)?sqrt(a*mode):1-sqrt((1-a)*(1-mode));
    }
}

var gausrand = func(spread,center) {
    var n=12;
    var sum=0.0;
    for(var i=0;i<n;i+=1)
        sum+=rand();
    n=spread*(sum-6)+center;
    return clip(n,0,1);
}

var betarand = func(a,b) {
    if(a <= 0 or b <= 0)
      return 0;
      
    var r1 = 0;
    var r2 = 2;

    while(r2>1) {
      var tmp = 0;
      while(!tmp)
        tmp = rand();
      r1 = pow(tmp, 1/a);
      var tmp = 0;
      while(!tmp)
        tmp = rand();
      r2 = r1 + pow(tmp, 1/b);
    }
    return r1/r2;
}

# convert probability density function
# to cumulative distribution function.
var pdf2cdf = func(v) {
    var v2 = setsize([],size(v));
    var last = 0;
    forindex(i;v2) {
        last += v[i];
        v2[i] = last;
    }

    # is there a better way to do this?
    var ratio = (size(v2)-1)/last;
    var v3 = setsize([],size(v2));
    var max=0;
    forindex(i;v2) {
        forindex(j;v2) {
            if(v2[j]*ratio >= i) {
                v3[i] = j;
                if(j>max) max=j;
                break;
            }
        }
    }
    
    # normalize
    forindex(i;v3)
        v3[i] /= max;

    return v3;
}

# user random distribution, v is a cumulative density function
var userrand = func(v) {
    var u = rand()*(size(v)-1);
    var i = int(u);
    var a = v[i];
    var b = v[i+1];
    var x = u - i;
    return a+((b-a)*x);
}

var rand2 = func(a,b) {a+rand()*(b-a); }
var irand2 = func(a,b) {round(rand2(a,b));}

# note: r must be in the range 0 to sum of p!
var _map = func(p,r) {
    var n = size(p);
    while(n) {
        n -= 1;
        if(r<p[n]) return n;
        r -= p[n];
    }
    return -1;
}

# return a random number between 0 and size(p).
# p is a vector of probabilities so that the sum
# is exactly 1.0.
var prand = func(p) { _map(p,rand()); }

# iterate a markov chain. tab is a vector of N
# vectors (rows) of N elements. Each row contains
# probabilities so that their sum is exactly 1.0.
# row is the value of the last iteration.
# Example:
#   x = 0;
#   for(i=0;i<100;i+=1) {
#     x = math.markov(tab, x);
#     print(x,"\n");
#   }
var markov = func(tab,row) { prand(tab[row]); }

# return a random element from vector v
var choose = func(v) { v[rand()*size(v)]; }

var linipol = func(a, b, x) {a+x*(b-a);}
var cosipol = func(a, b, x) {
    var f = (1 - cos(x * pi))/2;
    return a*(1-f) + b*f;
}
# (y0 and y3 is the points before and after the segment)
var cubipol = func(y0,y1,y2,y3,mu) {
   var mu2 = mu*mu;
   var a0 = y3 - y2 - y0 + y1;
   var a1 = y0 - y1 - a0;
   var a2 = y2 - y0;
   var a3 = y1;
   return a0*mu*mu2+a1*mu2+a2*mu+a3;
}

### borrowed from Andrew Ross original math.nas ###

var abs = func(n) { n < 0 ? -n : n }
var asin = func(y) { atan2(y, sqrt(1-y*y)) }
var acos = func(x) { atan2(sqrt(1-x*x), x) }
var _iln10 = 1/ln(10);
var log10 = func(x) { ln(x) * _iln10; }
