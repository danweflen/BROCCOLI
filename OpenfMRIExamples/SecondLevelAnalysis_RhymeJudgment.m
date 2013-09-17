%  	 BROCCOLI: An open source multi-platform software for parallel analysis of fMRI data on many core CPUs and GPUS
%    Copyright (C) <2013>  Anders Eklund, andek034@gmail.com
%
%    This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.
%-----------------------------------------------------------------------------

%---------------------------------------------------------------------------------------------------------------------
% README
% If you run this code in Windows, your graphics driver might stop working
% for large volumes / large filter sizes. This is not a bug in my code but is due to the
% fact that the Nvidia driver thinks that something is wrong if the GPU
% takes more than 2 seconds to complete a task. This link solved my problem
% https://forums.geforce.com/default/topic/503962/tdr-fix-here-for-nvidia-driver-crashing-randomly-in-firefox/
%---------------------------------------------------------------------------------------------------------------------

clear all
clc
close all

if ispc
    addpath('D:\nifti_matlab')    
    opencl_platform = 0;
    opencl_device = 0;
elseif isunix
    addpath('/home/andek/Research_projects/nifti_matlab')
    basepath = '/data/andek/OpenfMRI/';    
    opencl_platform = 2;
    opencl_device = 0;
    mex ../code/Matlab_Wrapper/SecondLevelAnalysis.cpp -lOpenCL -lBROCCOLI_LIB -I/usr/local/cuda-5.0/include/ -I/usr/local/cuda-5.0/include/CL -L/usr/lib -I/home/andek/Research_projects/BROCCOLI/BROCCOLI/code/BROCCOLI_LIB/ -L/home/andek/cuda-workspace/BROCCOLI_LIB/Release -I/home/andek/Research_projects/BROCCOLI/BROCCOLI/code/BROCCOLI_LIB/Eigen/
end

study = 'RhymeJudgment/ds003_models';
number_of_subjects = 13;

voxel_size = 2;

%--------------------------------------------------------------------------------------
% Statistical settings
%--------------------------------------------------------------------------------------

regress_confounds = 0;
number_of_permutations = 5000;

%--------------------------------------------------------------------------------------
% Load MNI templates
%--------------------------------------------------------------------------------------

MNI_brain_mask_nii = load_nii(['../brain_templates/MNI152_T1_' num2str(voxel_size) 'mm_brain_mask.nii']);
MNI_brain_mask = double(MNI_brain_mask_nii.img);
MNI_brain_mask = MNI_brain_mask/max(MNI_brain_mask(:));

[MNI_sy MNI_sx MNI_sz] = size(MNI_brain_mask);
[MNI_sy MNI_sx MNI_sz]

%--------------------------------------------------------------------------------------
% Load first level results
%--------------------------------------------------------------------------------------

first_level_results = zeros(MNI_sy,MNI_sx,MNI_sz,number_of_subjects);
for subject = 1:13
    if subject < 10
        beta_volume = load_nii([basepath study '/sub00' num2str(subject) '/model/model001/task001.gfeat/cope1.feat/stats/cope1.nii.gz']);
    else
        beta_volume = load_nii([basepath study '/sub0' num2str(subject) '/model/model001/task001.gfeat/cope1.feat/stats/cope1.nii.gz']);
    end
    beta_volume = double(beta_volume.img);
    first_level_results(:,:,:,subject) = beta_volume;
end


%--------------------------------------------------------------------------------------
% Create GLM regressors
%--------------------------------------------------------------------------------------

%X_GLM = zeros(number_of_subjects,13);
%X_GLM = zeros(number_of_subjects,10);
X_GLM = zeros(number_of_subjects,1);
for subject = 1:13
   X_GLM(subject,1) = subject; 
   %X_GLM(subject,2) = 1; 
   %X_GLM(subject,3) = randn; 
   %X_GLM(subject,4) = randn; 
   %X_GLM(subject,5) = randn; 
   %X_GLM(subject,6) = randn; 
   %X_GLM(subject,7) = randn; 
   %X_GLM(subject,8) = randn; 
   %X_GLM(subject,9) = randn; 
   %X_GLM(subject,10) = randn; 
   %X_GLM(subject,1) = 1; 
   %X_GLM(subject,subject) = 1; 
end



%for subject = 1:6
%   X_GLM(subject,1) = 1; 
%end
%for subject = 7:13
%   X_GLM(subject,1) = -1; 
%end

xtxxt_GLM = inv(X_GLM'*X_GLM)*X_GLM';

%--------------------------------------------------------------------------------------
% Load confound regressors
%--------------------------------------------------------------------------------------

% Calculate number of confounds

confounds = 1;


%--------------------------------------------------------------------------------------
% Setup contrasts
%--------------------------------------------------------------------------------------

% Contrasts for confounding regressors are automatically set to zeros by BROCCOLI 

contrasts = [1];

%contrasts = [1 0;
%             0 1]; 

%contrasts = [1 0 0 0 0 0 0 0 0 0;
%             0 1 0 0 0 0 0 0 0 0]; 

%contrasts = [1 0 0 0 0 0 0 0 0 0 0 0 0;
%             0 1 0 0 0 0 0 0 0 0 0 0 0]; 


for i = 1:size(contrasts,1)
    contrast = contrasts(i,:)';
    ctxtxc_GLM(i) = contrast'*inv(X_GLM'*X_GLM)*contrast;
end


%--------------------------------------------------------------------------------------
% Run second level analysis
%--------------------------------------------------------------------------------------


tic
[beta_volumes, residuals, residual_variances, statistical_maps, design_matrix1, design_matrix2, cluster_indices, null_distribution, permuted_first_level_results] = ... 
SecondLevelAnalysis(first_level_results,MNI_brain_mask, X_GLM,xtxxt_GLM',contrasts,ctxtxc_GLM, confounds,regress_confounds, number_of_permutations, opencl_platform, opencl_device);
toc



slice = round(0.5*MNI_sz);


%figure
%imagesc(MNI(:,:,slice)); colormap gray

figure
imagesc(beta_volumes(:,:,slice,1)); colormap gray; colorbar
title('Beta')

figure
imagesc(statistical_maps(:,:,slice,1)); colorbar
title('t-values')

figure
imagesc(cluster_indices(:,:,slice,1)); colorbar
title('Cluster indices')


slice = round(0.45*MNI_sz);

%figure
%imagesc(flipud(squeeze(MNI(slice,:,:))')); colormap gray

figure
imagesc(flipud(squeeze(beta_volumes(slice,:,:,1))')); colormap gray
title('Beta')

figure
imagesc(flipud(squeeze(statistical_maps(slice,:,:,1))')); colorbar
title('t-values')

figure
imagesc(residual_variances(:,:,slice)); colorbar
title('Residual variances')

s = sort(null_distribution);
threshold = s(round(0.95*number_of_permutations))

figure
hist(null_distribution,100)
