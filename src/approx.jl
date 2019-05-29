epsilon = 1e-6
approx(a, b) = a > b ? (a - b) < epsilon : (b - a) < epsilon

near_zero(a) = approx(a, 0)
