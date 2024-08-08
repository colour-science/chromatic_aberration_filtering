import time
import os

import numpy as np
import matplotlib.pyplot as plt
from skimage import io, img_as_float32, img_as_ubyte

from chromatic_aberration_correction import correct_chromatic_aberration

os.chdir(os.path.dirname(__file__))

impath = "../images/bridge_blurry.jpg"

img = img_as_float32(io.imread(impath))

L_hor = 14
L_ver = 4
rho = np.array([-0.25, 1.375, -0.125], dtype=img.dtype)
tau = 15.0 / 255
alpha_R = 0.5
alpha_B = 1.0
beta_R = 1.0
beta_B = 0.25
gamma_1 = 128.0 / 255
gamma_2 = 64.0 / 255

print("Use the parameters:")
print("  L_hor:  ", L_hor)
print("  L_ver:  ", L_ver)
print("  rho:    ", list(rho))
print("  tau:", tau)
print("  alpha_R:", alpha_R)
print("  alpha_B:", alpha_B)
print("  beta_R: ", beta_R)
print("  beta_B: ", beta_B)
print("  gamma_1:", gamma_1)
print("  gamma_2:", gamma_2)

# padding to remove gray lines at the borders
img = np.pad(img, [(L_ver, L_ver), (L_hor, L_hor), (0, 0)])

print("Start restoration...")
tic = time.time()

impred = correct_chromatic_aberration(
    img, L_hor, L_ver, rho, tau, alpha_R, alpha_B, beta_R, beta_B, gamma_1, gamma_2
)
toc = time.time()
print("Elapsed time: %2.2f sec" % (toc - tic))

# Cropping the borders
impred = impred[L_ver:-L_ver, L_hor:-L_hor]

plt.figure()
plt.subplot(1, 2, 1)
plt.imshow(img)
plt.subplot(1, 2, 2)
plt.imshow(impred)
plt.show()

print(impred.max(), impred.min())


io.imsave(impath.replace("_blurry.jpg", "_prediction.png"), img_as_ubyte(impred))

print("Done!")
