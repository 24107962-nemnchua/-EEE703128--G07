def peak_decay(samples, N=8, peak0=0):
    assert N >= 1
    peak=peak0
    count=0
    out=[]
    for x in samples:
        x=int(x)
        if x > peak:
            peak=x
            count=0
        elif N <= 1:
            peak=max(peak-1,0)
            count=0
        elif count == N-1:
            peak=max(peak-1,0)
            count=0
        else:
            count += 1
        out.append((peak,count))
    return out

def test_new_peak():
    r=peak_decay([10,5,20],N=8)
    assert [p for p,_ in r]==[10,10,20]
    assert r[2][1]==0

def test_lower_sample_not_immediate_update():
    r=peak_decay([100,50,50],N=8)
    assert [p for p,_ in r]==[100,100,100]

def test_decay_N8():
    r=peak_decay([10]+[0]*16,N=8)
    ys=[p for p,_ in r]
    assert ys[:8]==[10,10,10,10,10,10,10,10]
    assert ys[8]==9
    assert ys[16]==8

def test_decay_N1():
    r=peak_decay([10,0,0,0],N=1)
    assert [p for p,_ in r]==[10,9,8,7]

def test_zero_saturation():
    r=peak_decay([1]+[0]*8,N=1)
    assert [p for p,_ in r]==[1,0,0,0,0,0,0,0,0]

def test_new_peak_priority_on_decay_boundary():
    # At N=2, after first non-peak sample the counter is 1.
    # Next accepted sample is a new peak and must win over decay.
    r=peak_decay([10,1,20],N=2)
    assert [p for p,_ in r]==[10,10,20]
    assert r[-1][1]==0

def test_equal_peak_is_not_new_peak():
    r=peak_decay([10,10],N=8)
    assert [p for p,_ in r]==[10,10]

def test_small_vs_large_N():
    inp=[20]+[0]*20
    small=[p for p,_ in peak_decay(inp,N=2)]
    large=[p for p,_ in peak_decay(inp,N=8)]
    assert small[-1] < large[-1]

def test_counter_state():
    for N in [2,3,4,8,16]:
        r=peak_decay([100]+[0]*(N+2),N=N)
        assert r[0][1]==0
        assert all(0 <= c < N for _,c in r)

def test_randomized():
    import random
    random.seed(7)
    for _ in range(5000):
        N=random.randint(1,16)
        xs=[random.randint(0,255) for _ in range(30)]
        r=peak_decay(xs,N=N)
        for p,c in r:
            assert 0 <= p <= 255
            assert 0 <= c < N

if __name__=="__main__":
    test_new_peak()
    test_lower_sample_not_immediate_update()
    test_decay_N8()
    test_decay_N1()
    test_zero_saturation()
    test_new_peak_priority_on_decay_boundary()
    test_equal_peak_is_not_new_peak()
    test_small_vs_large_N()
    test_counter_state()
    test_randomized()
    print("G07 golden reference PASS")
