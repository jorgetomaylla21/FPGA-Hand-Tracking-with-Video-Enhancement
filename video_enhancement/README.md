# Video Enhancement Module
The codes for software verification of our design is located in [a. software testbench](<a. software testbench>).
* [gerenate_filter_coefficient.nb](https://github.com/sjb565/Fpgesture-controlled-video-enhancement/blob/main/video_enhancement/a.%20software%20testbench/generate_filter_coefficient.nb): generate upsampling filter coefficients on wolfram notebook
* [bicubic.py](https://github.com/sjb565/Fpgesture-controlled-video-enhancement/blob/main/video_enhancement/a.%20software%20testbench/bicubic.py): compares hardcoded bicubic interpolation coefficients vs. OpenCV upsampling methods
* [kernel_tb.ipynb](https://github.com/sjb565/Fpgesture-controlled-video-enhancement/blob/main/video_enhancement/a.%20software%20testbench/kernel_tb.ipynb): auto-generates random image patches and appropriate testbenches for each upsampling kernel type
* [filter_types.txt](https://github.com/sjb565/Fpgesture-controlled-video-enhancement/blob/main/video_enhancement/a.%20software%20testbench/filter_types.txt): definition of each upsampling filter used in systemverilog files
