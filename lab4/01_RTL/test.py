import numpy as np


U = [
    [-0.165956, 0.440649, -0.999771],
    [-0.395335, -0.706488, -0.815323],
    [-0.62748, -0.308879, -0.206465]
]

x1 = [-0.92189, -0.660339, 0.756285]
x2 = [-0.803306, -0.157785, 0.915779]


def sigmoid(x):
    return 1 / (1 + np.exp(-x))


if __name__ == "__main__":
    U = np.array(U)
    x1 = np.array(x1)
    x2 = np.array(x2)
    Ux1 = np.dot(U, x1)
    Ux2 = np.dot(U, x2)
    print('Ux1: ', Ux1)
    print('Ux2: ', Ux2)