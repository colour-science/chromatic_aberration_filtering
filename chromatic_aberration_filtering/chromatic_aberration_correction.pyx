"""
Correction of Axial and Lateral Chromatic Aberration With False Color Filter

References
----------
-   :cite:`Eboli2013` : Eboli, T. (2023). Fast Chromatic Aberration Correction with 1D Filters. Image Processing On Line, 13, 198–214. doi:10.5201/ipol.2023.443
"""

import numpy as np
cimport cython

# "cimport" is used to import special compile-time information
# about the numpy module (this is stored in a file numpy.pxd which is
# currently part of the Cython distribution).
cimport numpy as np

from cython.parallel cimport prange
from libc.math cimport fmin, fmax, fabs

__all__ = ["correct_chromatic_aberration"]

__version__ = "0.1.0.dev2"

# It's necessary to call "import_array" if you use any part of the
# numpy PyArray_* API. From Cython 3, accessing attributes like
# ".shape" on a typed Numpy array use this API. Therefore we recommend
# always calling "import_array" whenever you "cimport numpy"
np.import_array()

DTYPE = np.float32

# "ctypedef" assigns a corresponding compile-time type to DTYPE_t. For
# every type in the numpy module there's a corresponding compile-time
# type with a _t-suffix.
ctypedef np.float32_t DTYPE_t
ctypedef np.uint8_t uint8


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
cdef DTYPE_t[:, ::1] transpose(DTYPE_t[:, ::1] X):
    """
    Transpose given 2D array :math:`X`.

    Parameters
    ----------
    X 
        Input 2D array to be transposed.

    Returns
    -------
    ndarray
        Transposed 2D array.
    """

    cdef Py_ssize_t M = X.shape[0]
    cdef Py_ssize_t N = X.shape[1]
    cdef Py_ssize_t i, j
    cdef DTYPE_t[:, ::1] Xt = np.empty((N, M), dtype=DTYPE)

    for i in prange(0, M, 1, nogil=True):
        for j in range(0, N, 1):
            Xt[j, i] = X[i, j]
    return Xt


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
def correct_chromatic_aberration(np.ndarray[DTYPE_t, ndim=3] I_in, int L_hor, int L_ver,
                                 np.ndarray[DTYPE_t, ndim=1] rho, DTYPE_t tau, DTYPE_t alpha_R, DTYPE_t alpha_B, DTYPE_t beta_R,
                                 DTYPE_t beta_B, DTYPE_t gamma_1, DTYPE_t gamma_2):
    """
    Correct chromatic aberration in given input image :math:`I_{in}`.

    Parameters
    ----------
    I_in
        Input image of shape (M, N, 3) with dtype float32.
    L_hor
        Half-size of the horizontal 1D slice.
    L_ver
        Half-size of the vertical 1D slice.
    rho
        Three coefficients for prefiltering in TI stage.
    tau
        Threshold on chroma signal in FC stage.
    alpha_R
        Regularization parameter for red channel in FC stage.
    alpha_B
        Regularization parameter for blue channel in FC stage.
    beta_R
        Parameter for red channel in arbitration stage.
    beta_B
        Parameter for blue channel in arbitration stage.
    gamma_1
        First gamma parameter for arbitration weight calculation.
    gamma_2
        Second gamma parameter for arbitration weight calculation.

    Returns
    -------
    ndarray
        Corrected image of shape (M, N, 3) with dtype float32, clipped to [0, 1].

    References
    ----------
    :cite:`Eboli2013`
    """

    cdef Py_ssize_t M, N, i, j
    M = I_in.shape[0]
    N = I_in.shape[1]

    ## Introduction
    cdef DTYPE_t[:, ::1] R_in = np.empty((M, N), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] G_in = np.empty((M, N), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] B_in = np.empty((M, N), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] Y_in = np.empty((M, N), dtype=DTYPE)
    for i in prange(0, M, 1, nogil=True):
        for j in range(0, N, 1):
            R_in[i, j] = I_in[i, j, 0]
            G_in[i, j] = I_in[i, j, 1]
            B_in[i, j] = I_in[i, j, 2]
            Y_in[i, j] = 0.299 * R_in[i, j] + 0.587 * G_in[i, j] + 0.114 * B_in[i, j]

    ## Filtering
    # Horizontal pass
    cdef DTYPE_t[:, ::1] K_r_hor   = np.empty((M, N), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] K_rTI_hor = np.empty((M, N), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] R_max_hor = np.empty((M, N), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] R_min_hor = np.empty((M, N), dtype=DTYPE)
    ti_and_ca_filtering1D(R_in, G_in, Y_in, L_hor, rho, alpha_R, tau, K_r_hor, K_rTI_hor, R_max_hor, R_min_hor)
    cdef DTYPE_t[:, ::1] K_b_hor   = np.empty((M, N), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] K_bTI_hor = np.empty((M, N), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] B_max_hor = np.empty((M, N), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] B_min_hor = np.empty((M, N), dtype=DTYPE)
    ti_and_ca_filtering1D(B_in, G_in, Y_in, L_hor, rho, alpha_B, tau, K_b_hor, K_bTI_hor, B_max_hor, B_min_hor)

    # Vertical pass
    cdef DTYPE_t[:, ::1] K_r_ver   = np.empty((N, M), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] K_rTI_ver = np.empty((N, M), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] R_max_ver = np.empty((N, M), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] R_min_ver = np.empty((N, M), dtype=DTYPE)
    ti_and_ca_filtering1D(transpose(R_in), transpose(G_in), transpose(Y_in), L_ver, rho, alpha_R, tau,
                          K_r_ver, K_rTI_ver, R_max_ver, R_min_ver)
    cdef DTYPE_t[:, ::1] K_b_ver   = np.empty((N, M), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] K_bTI_ver = np.empty((N, M), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] B_max_ver = np.empty((N, M), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] B_min_ver = np.empty((N, M), dtype=DTYPE)
    ti_and_ca_filtering1D(transpose(B_in), transpose(G_in), transpose(Y_in), L_ver, rho, alpha_B, tau,
                          K_b_ver, K_bTI_ver, B_max_ver, B_min_ver)

    K_r_ver = transpose(K_r_ver)
    K_b_ver = transpose(K_b_ver)
    K_rTI_ver = transpose(K_rTI_ver)
    K_bTI_ver = transpose(K_bTI_ver)
    R_max_ver = transpose(R_max_ver)
    B_max_ver = transpose(B_max_ver)
    R_min_ver = transpose(R_min_ver)
    B_min_ver = transpose(B_min_ver)

    ## Arbitration
    # Build the 2D images from the vertically and the horizontally FC filtered images (Eqs. (16))
    # Kb
    cdef DTYPE_t[:, ::1] K_b = K_b_ver
    for i in prange(0, M, 1, nogil=True):
        for j in range(0, N, 1):
            if fabs(K_b_hor[i, j]) < fabs(K_b_ver[i, j]):
                K_b[i, j] = K_b_hor[i, j]

    #Kr
    cdef DTYPE_t[:, ::1] K_r = K_r_ver
    for i in prange(0, M, 1, nogil=True):
        for j in range(0, N, 1):
            if fabs(K_r_hor[i, j]) < fabs(K_r_ver[i, j]):
                K_r[i, j] = K_r_hor[i, j]

    # Build the 2D images from the vertically and the horizontally TI filtered images (Eqs. (18))
    # Kb_TI
    cdef DTYPE_t[:, ::1] K_bTI = K_bTI_ver
    cdef DTYPE_t[:, ::1] B_max = B_max_ver
    cdef DTYPE_t[:, ::1] B_min = B_min_ver
    for i in prange(0, M, 1, nogil=True):
        for j in range(0, N, 1):
            if fabs(K_bTI_hor[i, j]) < fabs(K_bTI_ver[i, j]):
                K_bTI[i, j] = K_bTI_hor[i, j]
                B_max[i, j] = B_max_hor[i, j]
                B_min[i, j] = B_min_hor[i, j]

    # Kr_TI
    cdef DTYPE_t[:, ::1] K_rTI = K_rTI_ver
    cdef DTYPE_t[:, ::1] R_max = R_max_ver
    cdef DTYPE_t[:, ::1] R_min = R_min_ver
    for i in prange(M, nogil=True):
        for j in range(0, N, 1):
            if fabs(K_rTI_hor[i, j]) < fabs(K_rTI_ver[i, j]):
                K_rTI[i, j] = K_rTI_hor[i, j]
                R_max[i, j] = R_max_hor[i, j]
                R_min[i, j] = R_min_hor[i, j]

    # Contrast arbitration
    cdef DTYPE_t[:, ::1] K_rout = np.empty((M, N), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] K_bout = np.empty((M, N), dtype=DTYPE)
    arbitration(K_r, K_rTI, R_in, G_in, R_max, R_min, beta_R, L_hor, L_ver, gamma_1, gamma_2, K_rout)
    arbitration(K_b, K_bTI, B_in, G_in, B_max, B_min, beta_B, L_hor, L_ver, gamma_1, gamma_2, K_bout)

    # Final RGB conversion (Eq. (24))
    cdef DTYPE_t[:, :, ::1] I_out = np.empty((M, N, 3), dtype=DTYPE)
    for i in prange(0, M, 1, nogil=True):
        for j in range(0, N, 1):
            I_out[i, j, 0] = K_rout[i, j] + G_in[i, j]
            I_out[i, j, 1] = G_in[i, j]
            I_out[i, j, 2] = K_bout[i, j] + G_in[i, j]

    return np.asarray(I_out)


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
cdef void grad(DTYPE_t[:, ::1] X, Py_ssize_t M, Py_ssize_t N, DTYPE_t[:, ::1] grad_X) nogil:
    """
    Compute the gradient of a 2D array along the second axis.

    Parameters
    ----------
    X : ndarray
        Input 2D array.
    M : int
        Number of rows in X.
    N : int
        Number of columns in X.
    grad_X : ndarray
        Output array to store the computed gradient.
    """

    cdef Py_ssize_t i, j
    for i in prange(0, M, 1, nogil=True):
        for j in range(1, N, 1):
            grad_X[i, j] = X[i, j] - X[i, j - 1]


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
cdef int sign(DTYPE_t input) nogil:
    """
    Compute the sign of a given number.

    Parameters
    ----------
    input : float
        Input number.

    Returns
    -------
    int
        1 if input is positive, -1 if negative, 0 if zero.
    """

    if input > 0:
        return 1
    elif input < 0:
        return -1
    else:
        return 0


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
cdef DTYPE_t clip(DTYPE_t K, DTYPE_t K_ref) nogil:
    """
    Clip given :math:`K` value based on :math:`K_ref` reference value.

    Parameters
    ----------
    K
        Input value to be clipped.
    K_ref
        Reference value for clipping.

    Returns
    -------
    float
        Clipped value.
    """

    ## Compute clip (Eq. (9))
    if K_ref > 0:
        return fmin(K, K_ref)
    elif K_ref < 0:
        return fmax(K, K_ref)
    else:
        return K_ref


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef void ti_and_ca_filtering1D(DTYPE_t[:, ::1] X_in, DTYPE_t[:, ::1] G_in, DTYPE_t[:, ::1] Y_in, int L,
                                DTYPE_t[::1] rho, DTYPE_t alpha_X, DTYPE_t tau, DTYPE_t[:, ::1] K_hor,
                                DTYPE_t[:, ::1] K_TI_hor, DTYPE_t[:, ::1] X_max, DTYPE_t[:, ::1] X_min):
    """
    Perform the 1D separable successive TI and FC 1D filtering.

    Parameters
    ----------
    X_in
        Input red or blue image.
    G_in
        Input green image.
    Y_in
        Input luma image.
    L
        Half-size of the 1D slice.
    rho
        The three coefficients for prefiltering in TI stage.
    alpha_X
        Regularization parameter in color gradient in FC stage.
    tau
        Threshold on chroma signal in FC stage.
    K_hor
        Output FC filtered image.
    K_TI_hor
        Output TI filtered image.
    X_max
        Output local maxima in TI stage.
    X_min
        Output local minima in TI stage.
    """

    cdef Py_ssize_t M, N, i, j
    cdef int l = 0
    cdef int LL = 2 * L + 1
    cdef DTYPE_t eps = 1e-8

    M = X_in.shape[0]
    N = X_in.shape[1]

    ## Compute the horizontal gradients
    cdef DTYPE_t[:, ::1] grad_X = np.empty((M, N), dtype=DTYPE)
    grad(X_in, M, N, grad_X)
    cdef DTYPE_t[:, ::1] grad_G = np.empty((M, N), dtype=DTYPE)
    grad(G_in, M, N, grad_G)
    # cdef DTYPE_t[:, ::1] grad_X = np.gradient(X_in, axis=-1)
    # cdef DTYPE_t[:, ::1] grad_G = np.gradient(G_in, axis=-1)

    cdef DTYPE_t[:, ::1] X_TImax = np.empty((M, LL), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] X_TImin = np.empty((M,LL), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] X_TI = np.empty((M, LL), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] X_pf = np.empty((M, LL), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] K_TI = np.empty((M, LL), dtype=DTYPE)
    cdef DTYPE_t[:, ::1] W_K = np.empty((M, LL), dtype=DTYPE)
    cdef DTYPE_t[::1] W_K_sum = np.empty(M, dtype=DTYPE)
    cdef DTYPE_t[::1] X_Emax = np.empty(M, dtype=DTYPE)
    cdef DTYPE_t[::1] X_Emin = np.empty(M, dtype=DTYPE)
    cdef DTYPE_t[::1] X_Wmax = np.empty(M, dtype=DTYPE)
    cdef DTYPE_t[::1] X_Wmin = np.empty(M, dtype=DTYPE)

    for i in prange(L, M - L, 1, nogil=True):
        for j in range(L, N - L, 1):
            W_K_sum[i] = 0
            X_Emax[i] = X_in[i, j]
            X_Emin[i] = X_in[i, j]
            X_Wmax[i] = X_in[i, j]
            X_Wmin[i] = X_in[i, j]

            ###### Transient improvement filtering
            ## Compute min and max on windows (Eq. (2)) (do it the recursive way)
            for l in range(0, L, 1):
                if X_in[i, j + l + 1] > X_Emax[i]:
                    X_Emax[i] = X_in[i, j + l + 1]
                if X_in[i, j + l + 1] < X_Emin[i]:
                    X_Emin[i] = X_in[i, j + l + 1]
                if X_in[i, j - L + l] > X_Wmax[i]:
                    X_Wmax[i] = X_in[i, j - L + l]
                if X_in[i, j - L + l] < X_Wmin[i]:
                    X_Wmin[i] = X_in[i, j - L + l]

            ## Select the best couple of values (Eq. (3))
            if (X_Emax[i] - X_Wmin[i]) >= (X_Wmax[i] - X_Emin[i]):
                X_max[i, j] = X_Emax[i]
                X_min[i, j] = X_Wmin[i]
            else:
                X_max[i, j] = X_Wmax[i]
                X_min[i, j] = X_Emin[i]

            for l in range(0, LL, 1):
                ## Main TI process (Eq. (1)) and Eq. (4)) (we use X_TI for X_pf as they are the same thing)
                if X_in[i, j] > G_in[i, j]:
                    X_pf[i, l] = rho[0] * X_max[i, j] + rho[1] * X_in[i, j + l - L] + rho[2] * X_min[i, j]
                    X_TImax[i, l] = X_in[i, j + l - L]
                    X_TImin[i, l] = fmax(X_min[i, j], G_in[i, j + l - L])
                else:
                    X_pf[i, l] = rho[0] * X_min[i, j] + rho[1] * X_in[i, j + l - L] + rho[2] * X_max[i, j]
                    X_TImax[i, l] = fmin(X_max[i, j], G_in[i, j + l - L])
                    X_TImin[i, l] = X_in[i, j + l - L]

                ## Clipping the filtered imaged in the admissible set on values (Eq. (5))
                if X_pf[i, l] > X_TImax[i, l]:
                    X_TI[i, l] = X_TImax[i, l]
                elif X_pf[i, l] < X_TImin[i, l]:
                    X_TI[i, l] = X_TImin[i, l]
                else:
                    X_TI[i, l] = X_pf[i, l]

                # RGB2KbKr conversion (Eq. (7))
                K_TI[i, l] = X_TI[i, l] - G_in[i, j + l - L]   # (2L+1)

                ##### False color filtering
                ## Computing W_K in Eq. (10)
                ## Chromaticity sign (Eq. (11))
                if (sign(K_TI[i, L]) == sign(K_TI[i, l])) or (fabs(K_TI[i, l]) < tau):
                    W_K[i, l] = 1
                else:
                    W_K[i, l] = 0

                ## Gradients' weights (Eq. (12))
                W_K[i, l] /= fabs(grad_G[i, j + l - L]) + \
                             fmax(fabs(grad_X[i, j + l - L]), alpha_X * fabs(K_TI[i, l])) + \
                             fabs(Y_in[i, j] - Y_in[i, j + l - L])  + eps

                ## Linear filtering with clipping (Eqs. (9) and (10))
                # K_hor[i, j] = K_hor[i, j] + W_K[i, l] * clip(K_TI[i, l], K_TI[i, L])
                # W_K_sum[i] = W_K_sum[i] + W_K[i, l]
                K_hor[i, j] += W_K[i, l] * clip(K_TI[i, l], K_TI[i, L])
                W_K_sum[i] += W_K[i, l]

            ## Linear filtering (Eqs. (9))
            K_hor[i, j] /= W_K_sum[i] + eps

            ## Save K_TI for arbitration
            K_TI_hor[i, j] = K_TI[i, L]


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef void arbitration(DTYPE_t[:, ::1] K, DTYPE_t[:, ::1] K_TI, DTYPE_t[:, ::1] X, DTYPE_t[:, ::1] G, DTYPE_t[:, ::1] X_max,
                      DTYPE_t[:, ::1] X_min, DTYPE_t beta_X, int L_hor, int L_ver, DTYPE_t gamma_1,
                      DTYPE_t gamma_2, DTYPE_t[:, ::1] K_out):
    """
    Perform the arbitration stage between the TI and FC filtered images.

    Parameters
    ----------
    K
        Output of FC stage, merge of horizontal and vertical filtered images.
    K_TI
        Output of TI stage.
    X
        Input red or blue image.
    G
        Input green image.
    X_max
        Local maxima from TI stage.
    X_min
        Local minima from TI stage.
    beta_X
        Parameter for arbitration stage.
    L_hor
        Half-size of horizontal 1D slice.
    L_ver
        Half-size of vertical 1D slice.
    gamma_1
        First gamma parameter for arbitration weight calculation.
    gamma_2
        Second gamma parameter for arbitration weight calculation.
    K_out
        Output arbitrated image.
    """


    cdef Py_ssize_t M, N, i, j
    cdef int l = 0
    M = X.shape[0]
    N = X.shape[1]

    #####################
    ## Horizontal pass ##
    #####################
    cdef int L = L_hor

    ## Compute the Contrast images (Eq. (20))
    cdef DTYPE_t[:, ::1] X_contrast_hor = np.empty((M, N), dtype=DTYPE)  # (M, N), horizontal pass
    cdef DTYPE_t[::1] Xp_max_hor = np.empty(M, dtype=DTYPE)
    cdef DTYPE_t[::1] Xp_min_hor = np.empty(M, dtype=DTYPE)

    cdef DTYPE_t[::1] X_Emax_hor = np.empty(M, dtype=DTYPE)
    cdef DTYPE_t[::1] X_Emin_hor = np.empty(M, dtype=DTYPE)
    cdef DTYPE_t[::1] X_Wmax_hor = np.empty(M, dtype=DTYPE)
    cdef DTYPE_t[::1] X_Wmin_hor = np.empty(M, dtype=DTYPE)

    for i in prange(L, M - L, 1, nogil=True):
        for j in range(L, N - L, 1):
            X_Emax_hor[i] = X[i, j]
            X_Emin_hor[i] = X[i, j]
            X_Wmax_hor[i] = X[i, j]
            X_Wmin_hor[i] = X[i, j]

            ## Recompute updated local max and min (Eq .(19))
            for l in range(0, L, 1):
                if (X[i, j + l] - beta_X * fabs(X[i, j + l] - G[i, j + l])) > X_Emax_hor[i]:
                    X_Emax_hor[i] = X[i, j + l] - beta_X * fabs(X[i, j + l] - G[i, j + l])
                if (X[i, j + l] + beta_X * fabs(X[i, j + l] - G[i, L + l])) < X_Emin_hor[i]:
                    X_Emin_hor[i] = X[i, j + l] + beta_X * fabs(X[i, j + l] - G[i, j + l])
                if (X[i, j - L + l + 1] - beta_X * fabs(X[i, j - L + l + 1] - G[i, j - L + l + 1])) > X_Wmax_hor[i]:
                    X_Wmax_hor[i] = X[i, j - L + l + 1] - beta_X * fabs(X[i, j - L + l + 1] - G[i, j - L + l + 1])
                if (X[i, j - L + l + 1] + beta_X * fabs(X[i, j - L + l + 1] - G[i, j - L + l + 1])) < X_Wmin_hor[i]:
                    X_Wmin_hor[i] = X[i, j - L + l + 1] + beta_X * fabs(X[i, j - L + l + 1] - G[i, j - L + l + 1])

            ## Select the best couple of values
            if (X_Emax_hor[i] - X_Wmin_hor[i]) >= (X_Wmax_hor[i] - X_Emin_hor[i]):
                Xp_max_hor[i] = X_Emax_hor[i]
                Xp_min_hor[i] = X_Wmin_hor[i]
            else:
                Xp_max_hor[i] = X_Wmax_hor[i]
                Xp_min_hor[i] = X_Emin_hor[i]
            X_contrast_hor[i, j] = Xp_max_hor[i] - Xp_min_hor[i]


    ###################
    ## Vertical pass ##
    ###################
    L = L_ver

    cdef DTYPE_t[:, ::1] X_contrast_ver = np.empty((N, M), dtype=DTYPE)  # (N, M), vertical pass
    cdef DTYPE_t[::1] Xp_max_ver = np.empty(N, dtype=DTYPE)
    cdef DTYPE_t[::1] Xp_min_ver = np.empty(N, dtype=DTYPE)

    cdef DTYPE_t[::1] X_Emax_ver = np.empty(N, dtype=DTYPE)
    cdef DTYPE_t[::1] X_Emin_ver = np.empty(N, dtype=DTYPE)
    cdef DTYPE_t[::1] X_Wmax_ver = np.empty(N, dtype=DTYPE)
    cdef DTYPE_t[::1] X_Wmin_ver = np.empty(N, dtype=DTYPE)

    cdef DTYPE_t[:, ::1] Xt = transpose(X)
    cdef DTYPE_t[:, ::1] Gt = transpose(G)

    for i in prange(L, N - L, 1, nogil=True):
        for j in range(L, M - L, 1):
            X_Emax_ver[i] = Xt[i, j]
            X_Emin_ver[i] = Xt[i, j]
            X_Wmax_ver[i] = Xt[i, j]
            X_Wmin_ver[i] = Xt[i, j]

            ## Recompute updated local max and min (Eq .(19))
            for l in range(0, L, 1):
                if (Xt[i, j + l + 1] - beta_X * fabs(Xt[i, j + l + 1] - Gt[i, j + l + 1])) > X_Emax_ver[i]:
                    X_Emax_ver[i] = Xt[i, j + l + 1] - beta_X * fabs(Xt[i, j + l + 1] - Gt[i, j + l + 1])
                if (Xt[i, j + l + 1] + beta_X * fabs(Xt[i, j + l + 1] - Gt[i, j + l + 1])) < X_Emin_ver[i]:
                    X_Emin_ver[i] = Xt[i, j + l + 1] + beta_X * fabs(Xt[i, j + l] + 1 - Gt[i, j + l + 1])
                if (Xt[i, j - L + l] - beta_X * fabs(Xt[i, j - L + l] - Gt[i, j - L + l])) > X_Wmax_ver[i]:
                    X_Wmax_ver[i] = Xt[i, j - L + l] - beta_X * fabs(Xt[i, j - L + l] - Gt[i, j - L + l])
                if (Xt[i, j - L + l] + beta_X * fabs(Xt[i, j - L + l] - Gt[i, j - L + l])) < X_Wmin_ver[i]:
                    X_Wmin_ver[i] = Xt[i, j - L + l] + beta_X * fabs(Xt[i, j - L + l] - Gt[i, j - L + l])

            ## Select the best couple of values
            if (X_Emax_ver[i] - X_Wmin_ver[i]) >= (X_Wmax_ver[i] - X_Emin_ver[i]):
                Xp_max_ver[i] = X_Emax_ver[i]
                Xp_min_ver[i] = X_Wmin_ver[i]
            else:
                Xp_max_ver[i] = X_Wmax_ver[i]
                Xp_min_ver[i] = X_Emin_ver[i]
            X_contrast_ver[i, j] = Xp_max_ver[i] - Xp_min_ver[i]
    X_contrast_ver = transpose(X_contrast_ver)  # (M, N)

    ## Compute X_contrast (Eq. (21))
    cdef DTYPE_t[:, ::1] X_contrast = X_contrast_ver
    for i in prange(0, M, 1, nogil=True):
        for j in range(0, N, 1):
            if X_contrast_hor[i, j] > X_contrast_ver[i, j]:
                X_contrast[i, j] = X_contrast_hor[i, j]

    ## Compute the arbitration weight (Eq. (22)) and the final filtered image (Eq. (17))
    cdef DTYPE_t [::1] alpha_K = np.empty(M, dtype=DTYPE)
    for i in prange(0, M, 1, nogil=True):
        for j in range(0, N, 1):
            alpha_K[i] = fmin(fmax(X_contrast[i, j], 0.0) / fmin(fmax(X_max[i, j] - X_min[i, j], gamma_2), gamma_1), 1.0)
            K_out[i, j] = (1 - alpha_K[i]) * K_TI[i, j] + alpha_K[i] * K[i, j]
