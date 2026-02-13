// Lightweight fixed-size RK4 helper for real-time friendly model integration.
// The closure only computes derivatives; the integrator handles stepping.
pub fn rk4_step<const N: usize, F>(state: &mut [f64; N], dt: f64, mut deriv: F)
where
    F: FnMut(&[f64; N], &mut [f64; N]),
{
    if !dt.is_finite() || dt <= 0.0 {
        return;
    }

    let mut k1 = [0.0; N];
    let mut k2 = [0.0; N];
    let mut k3 = [0.0; N];
    let mut k4 = [0.0; N];
    let mut tmp = [0.0; N];

    deriv(state, &mut k1);

    for i in 0..N {
        tmp[i] = state[i] + 0.5 * dt * k1[i];
    }
    deriv(&tmp, &mut k2);

    for i in 0..N {
        tmp[i] = state[i] + 0.5 * dt * k2[i];
    }
    deriv(&tmp, &mut k3);

    for i in 0..N {
        tmp[i] = state[i] + dt * k3[i];
    }
    deriv(&tmp, &mut k4);

    for i in 0..N {
        state[i] += (dt / 6.0) * (k1[i] + 2.0 * k2[i] + 2.0 * k3[i] + k4[i]);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rk4_exponential_decay() {
        let mut x = [1.0_f64];
        let dt = 0.01;
        for _ in 0..100 {
            rk4_step(&mut x, dt, |s, d| {
                d[0] = -s[0];
            });
        }
        // e^-1 ~= 0.367879
        assert!((x[0] - 0.367879).abs() < 2e-3);
    }
}
