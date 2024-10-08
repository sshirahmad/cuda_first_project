#include "../lib/augmentations.h"


ImageAugmentation::ImageAugmentation(int srcWidth, int srcHeight,
                                    int newWidth, int newHeight,
                                    int numChannels) :

                                    srcWidth(srcWidth), srcHeight(srcHeight),
                                    newWidth(newWidth), newHeight(newHeight),
                                    numChannels(numChannels)  {

                                        AllocateMemory();

                                    }


// Destructor
ImageAugmentation::~ImageAugmentation() {
    FreeMemory();
}


void ImageAugmentation::AllocateMemory(){

    cudaMalloc(&deviceInput, srcWidth * srcHeight * numChannels * sizeof(float));
    cudaMalloc(&deviceOutput, newWidth * newHeight * numChannels *  sizeof(float));
    h_nppOutput = nullptr;
    h_chwImage = nullptr;
}


void ImageAugmentation::FreeMemory(){

    cudaFree(deviceInput);
    cudaFree(deviceOutput);
    delete[] h_nppOutput;
    delete[] h_chwImage;

}


void ImageAugmentation::reset() {
    // Free previously allocated host memory
    delete[] h_nppOutput;

    // Reset pointers to new memory
    h_nppOutput = new float[newWidth * newHeight * numChannels];
    h_chwImage = new float[newWidth * newHeight * numChannels];

}

float* ImageAugmentation::augment(float* h_image){

    reset();

    cudaMemcpy(deviceInput, h_image, srcWidth * srcHeight * numChannels * sizeof(float), cudaMemcpyHostToDevice);

    resize();
    normalize();

    // Copy NPP output from device to host (temporary storage)
    cudaMemcpy(h_nppOutput, deviceOutput, newWidth * newHeight * numChannels * sizeof(float), cudaMemcpyDeviceToHost);

    // Convert NPP output from HWC to CHW format
    convertHWCtoCHW(h_nppOutput, h_chwImage);

    return h_chwImage;

}


// Method to normalize the image
void ImageAugmentation::normalize() {

    NppiSize srcSize = {newWidth, newHeight};
    int srcStep = newWidth * numChannels * sizeof(float);
    NppStatus status;

    if (numChannels == 3){
        Npp32f divisor[3] = {255, 255, 255}; 
        status = nppiDivC_32f_C3IR(
            divisor, deviceOutput, srcStep, srcSize
        );

    } else if (numChannels == 4){
        Npp32f divisor[4] = {255, 255, 255, 255}; 

        status = nppiDivC_32f_C4IR(
            divisor, deviceOutput, srcStep, srcSize
        );
    

    } else if (numChannels == 1){
        Npp32f divisor = 255; 
        status = nppiDivC_32f_C1IR(
            divisor, deviceOutput, srcStep, srcSize
        );

    }

    if (status != NPP_SUCCESS) {
        throw std::runtime_error("Failed to normalize the image using NPP.");
    }

    cudaDeviceSynchronize();

}

// Resizes the input image to a new width and height
void ImageAugmentation::resize() {

    NppiSize srcSize = {srcWidth, srcHeight};
    NppiRect srcRect = {0, 0, srcWidth, srcHeight};
    NppiSize dstSize = {newWidth, newHeight};
    NppiRect dstRect = {0, 0, newWidth, newHeight};
    NppStatus status;

    int srcStep = srcWidth * numChannels * sizeof(float);
    int dstStep = newWidth * numChannels * sizeof(float);

    if (numChannels == 3){

        status = nppiResize_32f_C3R(
            deviceInput, srcStep, srcSize, srcRect,
            deviceOutput, dstStep, dstSize, dstRect,
            NPPI_INTER_LINEAR
        );

    } else if (numChannels == 4){

        status = nppiResize_32f_C4R(
            deviceInput, srcStep, srcSize, srcRect,
            deviceOutput, dstStep, dstSize, dstRect,
            NPPI_INTER_LINEAR
        );
    

    } else if (numChannels == 1){

        status = nppiResize_32f_C1R(
            deviceInput, srcStep, srcSize, srcRect,
            deviceOutput, dstStep, dstSize, dstRect,
            NPPI_INTER_LINEAR
        );

    }

    if (status != NPP_SUCCESS) {
        throw std::runtime_error("Failed to resize the image using NPP.");
    }

    cudaDeviceSynchronize();
    
}


// Function to convert NPP output from HWC to CHW format
void ImageAugmentation::convertHWCtoCHW(const float* srcImage, float* chwImage) {

    for (int h = 0; h < newHeight; ++h) {
        for (int w = 0; w < newWidth; ++w) {
            for (int c = 0; c < numChannels; ++c) { 
                chwImage[c * newHeight * newWidth + h * newWidth + w] = srcImage[h * newWidth * numChannels + w * numChannels + c];
            }
        }
    }
}



