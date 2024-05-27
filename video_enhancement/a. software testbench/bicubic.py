import numpy as np
import torch
import torch.nn.functional as F
import math
import matplotlib.pyplot as plt
import cv2
import os, time, pickle

def np_psnr(original, upscaled):
    max_pixel = np.max(original)
    mse = np.square(original - upscaled).mean()
    return 20 * np.log10(max_pixel) - 10 * np.log10(mse)

def torch_psnr(original, upscaled):
    max_pixel = torch.max(original)
    mse = torch.square(original - upscaled).mean()
    return 20 * torch.log10(max_pixel) - 10 * torch.log10(mse)

# Each xii -> hard-coded convolution kernel
x00 = np.array(
      [[0, 0, 0, 0], 
       [0, 1, 0, 0], 
       [0, 0, 0, 0], 
       [0, 0, 0, 0]])
x10 = kernel1 = np.array(
      [[0, -9, 0, 0], 
       [0, 111, 0, 0], 
       [0, 29, 0, 0], 
       [0, -3, 0, 0]])/128
x20 = kernel2 = np.array(
      [[0, -1, 0, 0], 
       [0, 9, 0, 0], 
       [0, 9, 0, 0], 
       [0, -1, 0, 0]])/16
x30 = np.flip(x10, 0)

x01 = np.transpose(x10)
x11 = np.array(
      [[81, -999, -261, 27], 
       [-999, 12321, 3219, -333], 
       [-261, 3219, 841, -87], 
       [27, -333, -87, 9]])/2**14

# downscaled 1/32: 
kernel3 = np.array([[  3, -31,  -8,   0],
       [-31, 385, 101, -10],
       [ -8, 101,  26,  -3],
       [  0, -10,  -3,   0]])/2**9

x21 = np.array(
      [[9, -111, -29, 3], 
       [-81, 999, 261, -27], 
       [-81, 999, 261, -27], 
       [9, -111, -29, 3]])/2**11

# downscaled 1/4:
kernel4 = np.array([[  2, -28,  -7,   1],
       [-20, 250,  65,  -7],
       [-20, 250,  65,  -7],
       [  2, -28,  -7,   1]])/2**9


x31 = np.flip(x11, 0)

x02 = np.transpose(x20)
x12 = np.transpose(x21)
x22 = kernel5 = np.array(
      [[1, -9, -9, 1], 
       [-9, 81, 81, -9], 
       [-9, 81, 81, -9], 
       [1, -9, -9, 1]])/256
x32 = np.flip(x12, 0)

x03 = np.transpose(x30)
x13 = np.transpose(x31)
x23 = np.transpose(x32)
x33 = np.flip(x13, 0)

transform = torch.tensor(np.array([
    [x00, x01, x02, x03], 
    [x10, x11, x12, x13], 
    [x20, x21, x22, x23], 
    [x30, x31, x32, x33]
    ]))

def get_bicubic_spline(input):
    # Apply bicubic spline to input
    # Input size: (Channel, H, W)

    return torch.einsum('cij,hwij->chw', input, transform)

# Manual kernel for downscaling area x4 times (using area interpolation)
# Following kernel is used to overcome the issue of misalignment problem using
#      the cv2's innate downscale method
downscale_kernel = torch.Tensor([[1/4, 1/2, 1/2, 1/2, 1/4], 
                   [1/2, 1, 1, 1, 1/2], 
                   [1/2, 1, 1, 1, 1/2], 
                   [1/2, 1, 1, 1, 1/2],
                   [1/4, 1/2, 1/2, 1/2, 1/4]]).reshape((1,1,5,5)).to(torch.double)/16

def bicubic_spline_image(target):
    # (H, W, C) -> (C, H, W) for Torch convention
    target = target.transpose((2,0,1))
    C, H, W = target.shape

    # Crop to cleanly manageable size
    H, W = ((H-2)//16)*16+2, ((W-2)//16)*16+2
    target = target[:,:H,:W]

    target = torch.Tensor(target).to(torch.double)

    # proper 4x downscaling (area interpolation)
    downscaled = F.conv2d(target.reshape((C, 1, H, W)), 
                          downscale_kernel, 
                          stride=4, padding=0).squeeze()
    
    C, dH, dW = downscaled.shape
    output = torch.zeros((C, (dH-3)*4, (dW-3)*4))

    # sequential upscaling (equivalent to the FPGA implementation)
    start= time.time()
    for h in range(dH-3):
        for w in range(dW-3):
            patch = downscaled[:,h:h+4, w:w+4]
            bicubic_result = get_bicubic_spline(patch)
            output[:, 4*h:4*(h+1),4*w:4*(w+1)] = bicubic_result
    duration = time.time()-start
    
    # align target to the upscaled coordinate (margins cropped)
    target_aligned = target[:, 6:H-8, 6:W-8]

    original, upscaled = [
        image.to(torch.float32).numpy().transpose(1,2,0)
            for image in [target_aligned, output]
    ]
    psnr =  torch_psnr(target_aligned, output).item()

    return psnr, original, upscaled, duration

    # plt.imshow(target_aligned.to(torch.int).numpy().transpose(1,2,0))
    # plt.show()
    # plt.imshow(output.to(torch.int).numpy().transpose(1,2,0))
    # plt.show()
            

if __name__ == "__main__":
    W_target = 320 # resize width target
    nan = [float('inf'), float('-inf')]

    path = './images/'
    if not os.path.isdir(path):
        raise FileNotFoundError("./images/ directory and image files required for testing the result.")
    file_list = os.listdir(path)

    N = len(file_list)
    n_query = 10

    keys = [ 'spline', 'conv','bilinear', 'nearest']
    path_list = []
    hist = {
        key: [] for key in keys
    }
    query_time = {
        key: 0. for key in keys
    }
    method_dict = {
        'conv': cv2.INTER_CUBIC, 'bilinear': cv2.INTER_LINEAR, 
        'nearest': cv2.INTER_NEAREST
    }

    sample_result = {key: 0 for key in keys+['target',]}

    step = N//n_query
    for n in range(N-11, N, step):
        if n % 50 == 0 :
            print(f'{n//step}/{N//step}')
        f_path = os.path.join(path, file_list[n])

        # Load Image
        img = cv2.imread(f_path)
        H, W, C = img.shape

        # Set resolution to OV7670 camera (320 x 240) -- preserve image proportion
        H_target = int((H * W_target/W)) # resize to (%, 320)
        resized_img = cv2.resize(img, (W_target, H_target), interpolation=cv2.INTER_AREA)

        spline_psnr, target, upscaled, duration = bicubic_spline_image(resized_img)

        hist['spline'].append(spline_psnr)
        path_list.append(f_path)
        query_time['spline'] += duration
        sample_result['spline'] = upscaled
        sample_result['target'] = target

        H, W, C = target.shape
        if H%4 != 0 or W%4 != 0:
            raise ValueError(f"Resized image should be multiple of 4, but got {H, W}")
        
        downscaled_img = cv2.resize(target, (W//4, H//4), interpolation=cv2.INTER_AREA)

        # Compare with other traditional methods
        for method, val in method_dict.items():
            start= time.time()
            upscaled = cv2.resize(downscaled_img, 
                                  (W, H),
                                    interpolation = val)
            duration = time.time() - start
            psnr = np_psnr(target, upscaled)

            hist[method] = hist[method] + [psnr,]
            query_time[method] += duration
            sample_result[method] = upscaled
            
    avg_psnr = {
        method: np.array(hist[method]).mean() for method in keys
    }
    query_time = {
        method : query_time[method]/ n_query for method in keys
    }

    # with open('demo_result.pickle', 'wb') as handle:
    #     pickle.dump({'path': path_list,
    #                  'hist': hist,
    #                  'time': query_time,
    #                  'sample': sample_result}, handle, protocol=pickle.HIGHEST_PROTOCOL)

    print(avg_psnr)
    print(query_time)

    fig, ax =plt.subplots(1,5) # ax array
    sample = {
        key: sample_result[key].astype(int) for key in sample_result.keys()
    }
    title = ['GT','Bicubic Spline', 'Bicubic Conv.',
             'Bilinear', 'Nearest Neighbor']
    
    for i, method in enumerate(['target', 'spline', 'conv', 'bilinear', 'nearest']):
        ax[i].imshow(sample[method][:,:,::-1])

        ax[i].set_title(title[i])
        ax[i].set_xticks([])
        ax[i].set_yticks([])
        if i > 0:
            psnr = hist[method][-1]
            ax[i].set_xlabel(f'({psnr:.1f} dB)')

    plt.show()
