#!/usr/bin/env bash

version="06.18.2019";
set -e;
start_full_script=`date +%s`
script=`basename "$0"`

# Initial parameters
s1=6;
s2=5;
resample=4;
smoothing=12;
Kernel_Divider=40;
iteration=5000;

# Flag for optional parameters
VERBOSE=0;
SAVE=0;
c2d_executable_provided=0;
greedy_executable_provided=0;
resample_provided=0;
landmarks_provided=0;
apply_full_res=0;
apply_small_res=0;
moving_provided=0;
fixed_provided=0;
Output_provided=0;
tmp_dir_provided=0;

# Executables
greedy_executable="greedy";
c2d_executable="c2d";

function img_dim()
{
	image=${1?};
	which_dim=${2?};

	dim=`$c2d_executable $image -info-full \
	| grep Dim \
	| sed -e "s/\[//" -e "s/\]//" -e "s/,//" -e "s/.*: //" \
	| cut -d ' ' -f${which_dim}`;

	echo $dim;
}

echoV()
{
  #prerequisite: VERBOSE variable defined

  #echo only IF VERBOSE flag is on
  if [ ${VERBOSE} -eq 1 ];
  then
    echo -e $1;
  fi;
}

function Help {
  #echo_help_header;
  echo -e "${REGULAR_RED}";

  echo -e "\n";
  echo -e "  Description:";

  echo -e "\n";
  echo -e "  Fast, robust and accurate method for non-rigid 2D registration of very large images (tested with images with size up to 30kx30k pixels). This method takes less than 1 min on the cluster to compute the registration metrics but it can takes several minutes to apply these on the full resolution images (Depending on the size of the images). The method is robust to variable stains in histological images. It was applied in the ANHIR challenge for ISBI 2019 where it ranked 2nd, results can be see here : http://anhir.grand-challenge.org/Workshop-ISBI19/"
  echo -e "  Script written by Ludovic Venet, last update June 2019.";

  echo -e "\n";
  echo -e "  Usage:";

  echo -e "\n";
  echo -e "    Usage : ./$script -o /outdir/path -m /path/to/moving/image -f /path/to/fixed/image [-OPTIONAL arguments]";

  echo -e "\n";
  echo -e "  Compulsory Arguments:";

  echo -e "\n";
  echo -e "    -m	 [path]/full/path/to/${UNDERLINE_YELLOW}m${REGULAR_RED}oving/image";

  echo -e "\n";
  echo -e "    -f	 [path]/full/path/to/${UNDERLINE_YELLOW}f${REGULAR_RED}ixed/image";

  echo -e "\n";
  echo -e "    -o	 [path]/full/path/to/${UNDERLINE_YELLOW}o${REGULAR_RED}utput/directory";
  echo -e "    (must be directory)";
    
  echo -e "\n";
  echo -e "  Optional Arguments:";

  echo -e "\n";
  echo -e "    -c  [path]/path/to/${UNDERLINE_YELLOW}c${REGULAR_RED}2d/executable";
  echo -e "    (default=$c2d_executable, supposes that it was added to the PATH)"

  echo -e "\n";
  echo -e "    -g  [path]/path/to/${UNDERLINE_YELLOW}g${REGULAR_RED}reedy/executable";
  echo -e "    (default=$greedy_executable, supposes that it was added to the PATH)"

  echo -e "\n";
  echo -e "    -t	 [path]/full/path/to/${UNDERLINE_YELLOW}t${REGULAR_RED}emp/directory";
  echo -e "    (must be a directory)";
  echo -e "    (default in /tmp/)";

  echo -e "\n";
  echo -e "    -l	 [path]/full/path/to/${UNDERLINE_YELLOW}l${REGULAR_RED}andmarks";
  echo -e "    (must be csv with values XY starting 2nd ROW, 2nd LINE)";
  echo -e " ex: ,X,Y
     1,x,y
     2,x',y'
     ....
  with x,y;x',y' landmarks coordinates in the moving image space"

  echo -e "\n";
  echo -e "    -s	 [values]${UNDERLINE_YELLOW}s${REGULAR_RED}moothing/parameters/for/difeomorphic";
  echo -e "    (must be 2 values)";
  echo -e "    (default=$s1 $s2)";

  echo -e "\n";
  echo -e "    -r	 [value]${UNDERLINE_YELLOW}r${REGULAR_RED}esampling. Percentage of the full resolution images used for computation. Must be between 1 and 100, high values increase runtime.";
  echo -e "    (must be a percentage, but DO NOT add %)";
  echo -e "    (default=$resample)";

  echo -e "\n";
  echo -e "    -k	 [value]${UNDERLINE_YELLOW}k${REGULAR_RED}ernel divider. Define size of the kernel, it will be the size of the resampled image divided by this value. Small values will increase size of the kernel and so increase runtime.";
  echo -e "    (default=$Kernel_Divider)";  
  
  echo -e "\n";
  echo -e "    -V  [switch]${UNDERLINE_YELLOW}V${REGULAR_RED}ERBOSE mode on";
  echo -e "    (default=${VERBOSE})";

  echo -e "\n";
  echo -e "    -F  [switch]${UNDERLINE_YELLOW}F${REGULAR_RED}ULL resolution image reslice mode on";
  echo -e "    (default=${apply_full_res})";
  echo -e "    !!! Significaly increase runtime, use -L flag to apply it on the resampled images to check if registration worked." 

  echo -e "\n";
  echo -e "    -M  [switch]S${UNDERLINE_YELLOW}M${REGULAR_RED}ALL resolution image reslice mode on";
  echo -e "    (default=${apply_small_res})";
  echo -e "    Should be use for tunning parameters and to get an idea of the quality of the registration before applying it to the full resolution images. Outputs will be in the sshot/ folder in the output directory." 

  echo -e "\n";
  echo -e "    -S  [switch]${UNDERLINE_YELLOW}S${REGULAR_RED}AVE mode on";
  echo -e "    (default=${SAVE})";
  echo -e "    By default, only save metrics (Affine matrix and warp image) for resampled images and for full resolution images if -F flag ON. By switching it on, save metrics plus source, target and source registered to target for small images (with padding) and full resolution images (without padding) if -F flag ON."

  

  echo -e "${RESET_ALL}";
};



# get user inputs
while getopts m:f:o:l:g:c:k:s:r:i:hFVSM option
do
  case "${option}"
  in
    s) multi+=("$OPTARG");; #smoothing_parameters+=$OPTARD;;
    h)	Help;   #show help documentation
        #echo_system_information;  #show system information
        #echo_sge_default;         #show SGE default flag information
        exit 0;
        ;;
    m)  moving=${OPTARG};
	moving_provided=1;;   
    f)  fixed=${OPTARG};
	fixed_provided=1;;    
    o)	PATH_Output=${OPTARG};
	Output_provided=1;;
    l)  PATH_to_landmarks=${OPTARG};
	landmarks_provided=1;;
    t)  TEMP_Output=${OPTARG};
	tmp_dir_provided=1;;
    g)  greedy_executable=${OPTARG};
	greedy_executable_provided=1;;
    c)  c2d_executable=${OPTARG};
	c2d_executable_provided=1;;
    r)  resample=${OPTARG};
	resample_provided=1;;
    k) Kernel_Divider=${OPTARG};;
    i) iteration=${OPTARG};;
    V)	VERBOSE=1;
        #echoV "VERBOSE Mode on";
        ;;
    S) SAVE=1;
	echo "SAVE MODE ON";;
    F) apply_full_res=1;
	echo "Reslice full resolution images ON";;
    M) apply_small_res=1;
	echo "Reslice small resolution images ON";;
    ?)	echo "Unrecognized Options. Exiting. " 1>&2;
        Help;
        echo_system_information;
        echo_sge_default;
        exit 1;
        ;;
  esac
done;

# Check if all compulsory arguments are provided.
if [[ $moving_provided = 0 || $fixed_provided = 0 || $Output_provided = 0 ]];then
	echo "Error : Missing compulsory argument.
Usage : ./$script -o /outdir/path -m /path/to/moving/image -f /path/to/fixed/image [-OPTIONAL arguments]"
	exit 1;
fi

#Check if a temporary dir is provided, if not create one in /tmp/
if [[ $tmp_dir_provided = 0 ]];then
	TEMP_Output=`mktemp -d`
fi

# Check if 2 parameters for smoothing (greedy_deformable -s option).
if [[ $multi != "" ]];then
	s1=$multi;
	if [[ ${multi[1]} != "" ]];then
		s2=${multi[1]};
	else
		echo -e "Error: Only one smoothing parameters provided out of 2. Exiting.";
		exit 1;
	fi
fi

# Compute smoothing kernel for resampling. If 4% => new_size = Original_size / 25 => Kernel : 25 / 2 = 12vox
if [ $resample_provided -eq 1 ];then
	temp=`bc <<< 2*$resample`;
	smoothing=`bc <<< 100/$temp`;
fi

name_fixed=`basename $fixed | cut -d . -f1`;
name_moving=`basename $moving | cut -d . -f1`;

# Create Output and temporary directory
echoV "Creating output and temporary directories"
mkdir -p $PATH_Output/$name_moving"_registered_to_"$name_fixed;
mkdir -p $TEMP_Output;
PATH_Output=$PATH_Output/$name_moving"_registered_to_"$name_fixed;
mkdir -p $PATH_Output/metrics

# Extract size of images 
### !!! NEED TO BE REPLACE BY C2D !!! ###
Size_H_big=`img_dim $fixed 2`
Size_W_big=`img_dim $fixed 1`
Size_H_source_big=`img_dim $moving 2`
Size_W_source_big=`img_dim $moving 1`


# I/ Preproscessing
start=`date +%s`
echo "------------------------------------------------------------------------------------------"
echo "Preprocessing..."
echoV "Preprocessing I : Resample images"
# I/ 1/ Smoothing and resampling source and target to the disered resolution
# Target
echoV "Target"
echoV "$c2d_executable $fixed -smooth-fast $smoothing"x"$smoothing"vox" -resample $resample"%" -spacing 1x1mm -orient LP -origin 0x0mm -o $TEMP_Output/new_small_target.nii.gz;"
echoV "Source"
$c2d_executable $fixed -smooth-fast $smoothing"x"$smoothing"vox" -resample $resample"%" -spacing 1x1mm -orient LP -origin 0x0mm -o $TEMP_Output/new_small_target.nii.gz;

# Source
echoV "$c2d_executable $moving -smooth-fast $smoothing"x"$smoothing"vox" -resample $resample"%" -spacing 1x1mm -orient LP -origin 0x0mm -o $TEMP_Output/new_small_source.nii.gz;"
$c2d_executable $moving -smooth-fast $smoothing"x"$smoothing"vox" -resample $resample"%" -spacing 1x1mm -orient LP -origin 0x0mm -o $TEMP_Output/new_small_source.nii.gz;

# I/ 2/ Pad images.
echoV "Preprocessing II : Pad images"
echoV "Target"

# Get new size of images after resample
Size_W_init=`img_dim $TEMP_Output/new_small_target.nii.gz 1`
Size_H_init=`img_dim $TEMP_Output/new_small_target.nii.gz 2`

# Computes size kernel (depends of the size of the images and the Kernel_Divider parameters)
kernel_W=`bc <<< $Size_W_init/$Kernel_Divider`
kernel_H=`bc <<< $Size_H_init/$Kernel_Divider`

# Makes kernel a square
kernel=$kernel_H
if [[ $kernel_H -lt $kernel_W ]];then
	kernel=$kernel_W
fi

echoV "Size kernel : "$kernel"x"$kernel

# We want to pad with intensity as close as the background as possible.
# Extract mean and std of the intensities of the background (4 square of the size of the kernel at each corners)
echoV "Getting intensities in the four corners"
echoV "$c2d_executable $TEMP_Output/new_small_target.nii.gz -dup -cmv -popas Y -popas X -push X -thresh 0 $kernel 1 0 -push Y -thresh 0 $kernel 1 0 -times -popas c00 \
-push X -thresh $(($Size_W_init-$kernel)) $Size_W_init 1 0 -push Y -thresh 0 $kernel 1 0 -times -popas c01 \
-push X -thresh $(($Size_W_init-$kernel)) $Size_W_init 1 0 -push Y -thresh $(($Size_H_init-$kernel)) $Size_H_init 1 0 -times -popas c11 \
-push X -thresh 0 $kernel 1 0 -push Y -thresh $(($Size_H_init-$kernel)) $Size_H_init 1 0 -times -popas c10 \
-push c00 -push c01 -push c11 -push c10 -add -add -add -lstat | grep " 1 ""
stat_target=`$c2d_executable $TEMP_Output/new_small_target.nii.gz -dup -cmv -popas Y -popas X -push X -thresh 0 $kernel 1 0 -push Y -thresh 0 $kernel 1 0 -times -popas c00 \
-push X -thresh $(($Size_W_init-$kernel)) $Size_W_init 1 0 -push Y -thresh 0 $kernel 1 0 -times -popas c01 \
-push X -thresh $(($Size_W_init-$kernel)) $Size_W_init 1 0 -push Y -thresh $(($Size_H_init-$kernel)) $Size_H_init 1 0 -times -popas c11 \
-push X -thresh 0 $kernel 1 0 -push Y -thresh $(($Size_H_init-$kernel)) $Size_H_init 1 0 -times -popas c10 \
-push c00 -push c01 -push c11 -push c10 -add -add -add -lstat | grep " 1 "`

mean_target=`echo $stat_target | cut -d ' ' -f2`
std_target=`echo $stat_target | cut -d ' ' -f3`

echoV "Same with source"
# Same idea with source
# Get new size of images after resample
Size_W_source_init=`img_dim $TEMP_Output/new_small_source.nii.gz 1`
Size_H_source_init=`img_dim $TEMP_Output/new_small_source.nii.gz 2`

# Computes size kernel
kernel_H_source=`bc <<< $Size_H_source_init/$Kernel_Divider`
kernel_W_source=`bc <<< $Size_W_source_init/$Kernel_Divider`

# Makes kernel a square
kernel_source=$kernel_H_source
if [[ $kernel_H_source -lt $kernel_W_source ]];then
	kernel_source=$kernel_W_source
fi

echoV "Size kernel source : "$kernel_source"x"$kernel_source

# Extract mean and std of the intensities of the background (4 square of the size of the kernel at each corners)
echoV "Getting intensities in the four corners"
echoV "$c2d_executable $TEMP_Output/new_small_source.nii.gz -dup -cmv -popas Y -popas X -push X -thresh 0 $kernel_source 1 0 -push Y -thresh 0 $kernel_source 1 0 -times -popas c00 \
-push X -thresh $(($Size_W_source_init-$kernel_source)) $Size_W_source_init 1 0 -push Y -thresh 0 $kernel_source 1 0 -times -popas c01 \
-push X -thresh $(($Size_W_source_init-$kernel_source)) $Size_W_source_init 1 0 -push Y -thresh $(($Size_H_source_init-$kernel_source)) $Size_H_source_init 1 0 -times -popas c11 \
-push X -thresh 0 $kernel_source 1 0 -push Y -thresh $(($Size_H_source_init-$kernel_source)) $Size_H_source_init 1 0 -times -popas c10 \
-push c00 -push c01 -push c11 -push c10 -add -add -add -lstat | grep " 1 ""
stat_source=`$c2d_executable $TEMP_Output/new_small_source.nii.gz -dup -cmv -popas Y -popas X -push X -thresh 0 $kernel_source 1 0 -push Y -thresh 0 $kernel_source 1 0 -times -popas c00 \
-push X -thresh $(($Size_W_source_init-$kernel_source)) $Size_W_source_init 1 0 -push Y -thresh 0 $kernel_source 1 0 -times -popas c01 \
-push X -thresh $(($Size_W_source_init-$kernel_source)) $Size_W_source_init 1 0 -push Y -thresh $(($Size_H_source_init-$kernel_source)) $Size_H_source_init 1 0 -times -popas c11 \
-push X -thresh 0 $kernel_source 1 0 -push Y -thresh $(($Size_H_source_init-$kernel_source)) $Size_H_source_init 1 0 -times -popas c10 \
-push c00 -push c01 -push c11 -push c10 -add -add -add -lstat | grep " 1 "`

mean_source=`echo $stat_source | cut -d ' ' -f2`
std_source=`echo $stat_source | cut -d ' ' -f3`

# Computes 4 times the size of the kernel for futur padding. Pad with 4 times the size of the kernel to be sure that ROI far enough from boundaries.
echoV "Computing 4 times the size of the target kernel"
four_kernel_H=`bc <<< $kernel*4`
four_kernel_W=`bc <<< $kernel*4`
echoV "Four kernel : "$four_kernel_W"x"$four_kernel_H

# Compare source and target size and pad them to match them
echoV "Matching source and target sizes"
echoV "Size small target : "$Size_W_init"x"$Size_H_init
echoV "Size small source : "$Size_W_source_init"x"$Size_H_source_init
New_size_H=$Size_H_init
New_size_W=$Size_W_init
if [[ $Size_H_source_init"x"$Size_W_source_init != $Size_H_init"x"$Size_W_init ]];then

	echoV "Images sizes are different"
	echoV "Modifying sizes"

	# Compare size of both images and keep the larger
	if [[ $Size_H_init -lt $Size_H_source_init ]];then
		New_size_H=$Size_H_source_init
	fi	
	if [[ $Size_H_source_init -lt $Size_H_init ]];then
		New_size_H=$Size_H_init
	fi
	if [[ $Size_W_init -lt $Size_W_source_init ]];then
		New_size_W=$Size_W_source_init
	fi
	if [[ $Size_W_source_init -lt $Size_W_init ]];then
		New_size_W=$Size_W_init
	fi

	# First padding with zeros.
	# pad images to the desired size with zeros, if one is already of the desired size the command will not modify it
	echoV "$c2d_executable $TEMP_Output/new_small_target.nii.gz -pad-to $New_size_W"x"$New_size_H 0 -o $TEMP_Output/new_small_target_padded.nii.gz	"
	$c2d_executable $TEMP_Output/new_small_target.nii.gz -pad-to $New_size_W"x"$New_size_H 0 -o $TEMP_Output/new_small_target_padded.nii.gz	

	echoV "$c2d_executable $TEMP_Output/new_small_source.nii.gz -pad-to $New_size_W"x"$New_size_H 0 -o $TEMP_Output/new_small_source_padded.nii.gz"
	$c2d_executable $TEMP_Output/new_small_source.nii.gz -pad-to $New_size_W"x"$New_size_H 0 -o $TEMP_Output/new_small_source_padded.nii.gz
else
	echoV "Sizes are the same"
	# If images already of the same size just rename them
	cp $TEMP_Output/new_small_source.nii.gz $TEMP_Output/new_small_source_padded.nii.gz
	cp $TEMP_Output/new_small_target.nii.gz $TEMP_Output/new_small_target_padded.nii.gz
fi 

echoV "Padding target"
# We don't want to pad with zeros but with intensity close to the background.
# Target 
# a/
# Create a mask segmenting original images from its padded part (0 for padded pixels and 1 for original ones)
# Then pad it with 0 by 4 times the kernel to be sure that ROI far enough from the boundaries of the images.
echoV "$c2d_executable $TEMP_Output/new_small_target_padded.nii.gz \
-thresh 1 inf 1 0 \
-pad $four_kernel_W"x"$four_kernel_H $four_kernel_W"x"$four_kernel_H 0 \
-o $TEMP_Output/mask_target.nii.gz"
$c2d_executable $TEMP_Output/new_small_target_padded.nii.gz \
-thresh 1 inf 1 0 \
-pad $four_kernel_W"x"$four_kernel_H $four_kernel_W"x"$four_kernel_H 0 \
-o $TEMP_Output/mask_target.nii.gz

# b/
# Inverse this mask (1 for padded pixels and 0 for original pixels)
# Replace every pixels values in the first mask by 1
# Then scale this mask by the mean of the intenistites in the 4 corners and add a gaussian noise of the standart deviation of this intensity.
# Finaly multiply both mask together so final result have intensity 0 for each pixels that belongs to the original images and intensity close to the background for each padded pixels.
echoV "$c2d_executable $TEMP_Output/mask_target.nii.gz \
-replace 0 1 1 0 -popas invmask \
$TEMP_Output/mask_target.nii.gz -replace 0 1 1 1 -scale $mean_target -noise-gaussian $std_target \
-push invmask -times \
-o $TEMP_Output/mask_target.nii.gz"
$c2d_executable $TEMP_Output/mask_target.nii.gz \
-replace 0 1 1 0 -popas invmask \
$TEMP_Output/mask_target.nii.gz -replace 0 1 1 1 -scale $mean_target -noise-gaussian $std_target \
-push invmask -times \
-o $TEMP_Output/mask_target.nii.gz

# c/
# Pad the target image with 0 by 4 times the size of the kernels so it has the same size as the mask we just computed.
echoV "$c2d_executable $TEMP_Output/new_small_target_padded.nii.gz \
-pad $four_kernel_W"x"$four_kernel_H $four_kernel_W"x"$four_kernel_H 0 \
-o $TEMP_Output/new_small_target_padded.nii.gz"
$c2d_executable $TEMP_Output/new_small_target_padded.nii.gz \
-pad $four_kernel_W"x"$four_kernel_H $four_kernel_W"x"$four_kernel_H 0 \
-o $TEMP_Output/new_small_target_padded.nii.gz

# d/
# Add mask to the image padded with zeros, so it is now padded with the mean of the intensities in the four corners + a gaussian noise of the standart deviation of this intensity.
echoV "$c2d_executable $TEMP_Output/mask_target.nii.gz $TEMP_Output/new_small_target_padded.nii.gz \
-add \
-o $TEMP_Output/new_small_target_padded.nii.gz"
$c2d_executable $TEMP_Output/mask_target.nii.gz $TEMP_Output/new_small_target_padded.nii.gz \
-add \
-o $TEMP_Output/new_small_target_padded.nii.gz

echoV "Padding source"
# Same idea with source.
# a/
echoV "$c2d_executable $TEMP_Output/new_small_source_padded.nii.gz \
-thresh 1 inf 1 0 \
-pad $four_kernel_W"x"$four_kernel_H $four_kernel_W"x"$four_kernel_H 0 \
-o $TEMP_Output/mask_source.nii.gz"
$c2d_executable $TEMP_Output/new_small_source_padded.nii.gz \
-thresh 1 inf 1 0 \
-pad $four_kernel_W"x"$four_kernel_H $four_kernel_W"x"$four_kernel_H 0 \
-o $TEMP_Output/mask_source.nii.gz

# b/
echoV "$c2d_executable $TEMP_Output/mask_source.nii.gz \
-replace 0 1 1 0 -popas invmask \
$TEMP_Output/mask_source.nii.gz -replace 0 1 1 1 -scale $mean_source -noise-gaussian $std_source \
-push invmask -times \
-o $TEMP_Output/mask_source.nii.gz"
$c2d_executable $TEMP_Output/mask_source.nii.gz \
-replace 0 1 1 0 -popas invmask \
$TEMP_Output/mask_source.nii.gz -replace 0 1 1 1 -scale $mean_source -noise-gaussian $std_source \
-push invmask -times \
-o $TEMP_Output/mask_source.nii.gz

# c/
echoV "$c2d_executable $TEMP_Output/new_small_source_padded.nii.gz \
-pad $four_kernel_W"x"$four_kernel_H $four_kernel_W"x"$four_kernel_H 0 \
-o $TEMP_Output/new_small_source_padded.nii.gz"
$c2d_executable $TEMP_Output/new_small_source_padded.nii.gz \
-pad $four_kernel_W"x"$four_kernel_H $four_kernel_W"x"$four_kernel_H 0 \
-o $TEMP_Output/new_small_source_padded.nii.gz

# d/
echoV "$c2d_executable $TEMP_Output/mask_source.nii.gz $TEMP_Output/new_small_source_padded.nii.gz \
-add \
-o $TEMP_Output/new_small_source_padded.nii.gz"
$c2d_executable $TEMP_Output/mask_source.nii.gz $TEMP_Output/new_small_source_padded.nii.gz \
-add \
-o $TEMP_Output/new_small_source_padded.nii.gz

echoV "End preprocessing."
end=`date +%s`
runtime_preproc=$(($end-$start))
echo "Preprocessing took :" $runtime_preproc" secondes"


# Get new size of source and target images after padding
Size_W=`img_dim $TEMP_Output/new_small_target_padded.nii.gz 1`
Size_H=`img_dim $TEMP_Output/new_small_target_padded.nii.gz 2`

Size_W_source=`img_dim $TEMP_Output/new_small_source_padded.nii.gz 1`
Size_H_source=`img_dim $TEMP_Output/new_small_source_padded.nii.gz 2`

echoV "Size small target : "$Size_W"x"$Size_H
echoV "Size small source : "$Size_W_source"x"$Size_H_source

# II/ Registration
# II/ 1/ Affine
echo "------------------------------------------------------------------------------------------"
echo "Computing registration..."
echoV "Registration parameters : "
echoV "NCC Affine : "$kernel"x"$kernel
echoV "NCC Deformable : "$kernel"x"$kernel
echoV "********************"
echoV "Computing affine registration"

# Compute offset for brute force search for initial transformation. 
# !!!! ADD OFFSET AS A PARAMETERS !!!! SAME FOR  number_of_it and angle
offset=`bc <<< $Size_W/10`

# Start timer
start=`date +%s`

echoV "$greedy_executable -d 2 \
-a -search $iteration 180 $offset \
-m NCC $kernel"x"$kernel \
-i $TEMP_Output/new_small_target_padded.nii.gz $TEMP_Output/new_small_source_padded.nii.gz \
-o $TEMP_Output/small_Affine.mat \
-gm-trim $kernel"x"$kernel \
-n 100x50x10 \
-ia-image-centers"
$greedy_executable -d 2 \
-a -search $iteration 180 $offset \
-m NCC $kernel"x"$kernel \
-i $TEMP_Output/new_small_target_padded.nii.gz $TEMP_Output/new_small_source_padded.nii.gz \
-o $TEMP_Output/small_Affine.mat \
-gm-trim $kernel"x"$kernel \
-n 100x50x10 \
-ia-image-centers

end_affine=`date +%s`

# II/ 2/ Diffeomorphic
echoV "Computing non-rigid registration"

echoV "$greedy_executable -d 2 \
-m NCC $kernel"x"$kernel \
-i $TEMP_Output/new_small_target_padded.nii.gz $TEMP_Output/new_small_source_padded.nii.gz \
-it $TEMP_Output/small_Affine.mat \
-o $TEMP_Output/small_warp.nii.gz \
-oinv $TEMP_Output/small_inv_warp.nii.gz \
-n 100x50x10 \
-s $s1"vox" $s2"vox""
$greedy_executable -d 2 \
-m NCC $kernel"x"$kernel \
-i $TEMP_Output/new_small_target_padded.nii.gz $TEMP_Output/new_small_source_padded.nii.gz \
-it $TEMP_Output/small_Affine.mat \
-o $TEMP_Output/small_warp.nii.gz \
-oinv $TEMP_Output/small_inv_warp.nii.gz \
-n 100x50x10 \
-s $s1"vox" $s2"vox"

# End timer and echo time.
end=`date +%s`

runtime_aff=$(($end_affine-$start))
runtime_deff=$(($end-$end_affine))
runtime_reg=$(($end-$start))

echo "Computation of the affine matrix took :" $runtime_aff" secondes"
echo "Computation of the deformable field took :" $runtime_deff" secondes"
echo "Computation of the both deformable and affine registration took :" $runtime_reg" secondes"

echo "------------------------------------------------------------------------------------------"
echo "Adaptating small metrics to full resolution images..."
start=`date +%s`
# Adapt small_affine and small_warp to full resolution images
# Adapt affine matrix to full resolution, multiply translation vector of the matrix by the scale we resampled the image. For example with 4%, size of the image is divided by 25 so we multiply the translation part of the matrix by 25. 
# Rotation scaling and shearing stay the same.
# !!! Complicated code for a simple task, can probably be simplified.
echoV "Modifying affine matrix..."
tr ' ' ',' <$TEMP_Output/small_Affine.mat> $TEMP_Output/temp.mat

lines=`cat $TEMP_Output/temp.mat`
rm -f $TEMP_Output/Affine.mat

i=0

for line in $lines
do
	if [[ $i -lt 2 ]];then
		line_to_keep=`echo $line | cut -d , -f1-2`
		translation_to_change=`echo $line | cut -d , -f3`
		#new_translation=`echo $(( $translation_to_change * 25 ))`
		factor=`bc <<< 100/$resample`
		new_translation=`bc <<< $translation_to_change*$factor`
		new_line=$line_to_keep","$new_translation
	fi
	if [[ $i -eq 2 ]];then
		new_line=$line
	fi
	echo $new_line >> $TEMP_Output/temp_Affine.mat
	
	i=`bc <<< $i+1`
done

tr ',' ' ' <$TEMP_Output/temp_Affine.mat> $TEMP_Output/Affine.mat


echoV "Modifying warp..."

# We want to apply transformation to the original images that are NOT PADDED.
# Get size difference between small padded images and small images before padding.
Diff_W_Target=`bc <<< $Size_W-$Size_W_init`
Diff_H_Target=`bc <<< $Size_H-$Size_H_init`

# Create a 1 intensity image of the size of the full resolution target without padding
echoV "Creating new image of the size of the original target..."
echoV "$c2d_executable -background 1 \
-create $Size_W_init"x"$Size_H_init 1x1mm \
-orient LP \
-o $TEMP_Output/mask_no_pad.nii.gz"
$c2d_executable -background 1 \
-create $Size_W_init"x"$Size_H_init 1x1mm \
-orient LP \
-o $TEMP_Output/mask_no_pad.nii.gz

# Pad this image with 0 to the size of the full resolution target after padding. We have now a mask with intensity 1 for pixel that belongs to the original target image and intensity 0 for pixels that belogns to the padded part of the image.
echoV "Padding this new image to full resolution with padding..."
echoV "$c2d_executable $TEMP_Output/mask_no_pad.nii.gz \
-pad-to $Size_W"x"$Size_H 0 \
-o $TEMP_Output/mask_padded.nii.gz"
$c2d_executable $TEMP_Output/mask_no_pad.nii.gz \
-pad-to $Size_W"x"$Size_H 0 \
-o $TEMP_Output/mask_padded.nii.gz

# Change origin of the mask so it matches the one of the full resolution warp image. 
echoV "Modifying origin..."
echoV "$c2d_executable $TEMP_Output/mask_padded.nii.gz \
-origin 0x0mm \
-o $TEMP_Output/mask_padded.nii.gz"
$c2d_executable $TEMP_Output/mask_padded.nii.gz \
-origin 0x0mm \
-o $TEMP_Output/mask_padded.nii.gz

echoV "Modifying origin..."
echoV "$c2d_executable -mcs $TEMP_Output/small_warp.nii.gz \
-origin 0x0mm \
-omc $TEMP_Output/small_warp.nii.gz"
$c2d_executable -mcs $TEMP_Output/small_warp.nii.gz \
-origin 0x0mm \
-omc $TEMP_Output/small_warp.nii.gz

# Multiply the mask and the full resolution warp image to force to 0 every value in the padded part of the warp image.
echoV "Multiplying both images together..."
echoV "$c2d_executable $TEMP_Output/mask_padded.nii.gz -popas mask \
-mcs $TEMP_Output/small_warp.nii.gz \
-foreach \
-push mask -times \
-endfor \
-omc $TEMP_Output/small_warp_no_pad.nii.gz"
$c2d_executable $TEMP_Output/mask_padded.nii.gz -popas mask \
-mcs $TEMP_Output/small_warp.nii.gz \
-foreach \
-push mask -times \
-endfor \
-omc $TEMP_Output/small_warp_no_pad.nii.gz

# trim the warp image to remove every pixels with intensity 0 that are on the border of the image, ie every pixels that belongs to the padded part of the warp image.
echoV "Trim the result image to remove padded part..."
echoV "$c2d_executable -mcs $TEMP_Output/small_warp_no_pad.nii.gz \
-foreach \
-trim 0vox \
-endfor \
-omc $TEMP_Output/small_warp_no_pad_trim.nii.gz"
$c2d_executable -mcs $TEMP_Output/small_warp_no_pad.nii.gz \
-foreach \
-trim 0vox \
-endfor \
-omc $TEMP_Output/small_warp_no_pad_trim.nii.gz

end=`date +%s`
runtime_small_to_big=$(($end-$start))

echo "Adaptation of small warp and small affine matrix to full resolution images took :" $runtime_small_to_big" secondes"

# Apply transformation on landmarks if they're provided
if [ $landmarks_provided -eq 1 ];then
	echo "------------------------------------------------------------------------------------------"
	echo "Applying trasnformations on the landmarks"
	start=`date +%s`

	# PATH to landmarks csv and to temporary csv needed for computation
	LM_MOVING_FULL=$PATH_to_landmarks
	LM_MOVING_SMALL=$TEMP_Output/lm_small_source.csv
	LM_WARPED_SMALL=$TEMP_Output/lm_small_source_warped.csv
	LM_WARPED_FULL=$PATH_Output/warped_landmarks.csv

	# Step 1: map source landmarks into small image space
	echoV "Step 1: map source landmarks into small image space"
	echoV "cat $LM_MOVING_FULL \
	  | awk -F, -v wbig=$Size_W_source_big -v hbig=$Size_H_source_big \
	    -v wsmall=$Size_W_source_init -v hsmall=$Size_H_source_init \
	    'NR > 1 {printf("%f,%f\n",($2*1.0*wsmall)/wbig-0.5,($3*1.0*hsmall)/hbig-0.5)}' \
	    > $LM_MOVING_SMALL"
	cat $LM_MOVING_FULL \
	  | awk -F, -v wbig=$Size_W_source_big -v hbig=$Size_H_source_big \
	    -v wsmall=$Size_W_source_init -v hsmall=$Size_H_source_init \
	    'NR > 1 {printf("%f,%f\n",($2*1.0*wsmall)/wbig-0.5,($3*1.0*hsmall)/hbig-0.5)}' \
	    > $LM_MOVING_SMALL

	# Step 2: apply inverse warp and inverse affine to the moving landmarks
	echoV "Step 2: apply inverse warp and inverse affine to the moving landmarks"
	echoV "$greedy_executable -d 2 \
	  -rf $TEMP_Output/new_small_source.nii.gz -rs $LM_MOVING_SMALL $LM_WARPED_SMALL \
	  -r $TEMP_Output/small_Affine.mat,-1 $TEMP_Output/small_inv_warp.nii.gz"
	$greedy_executable -d 2 \
	  -rf $TEMP_Output/new_small_source.nii.gz -rs $LM_MOVING_SMALL $LM_WARPED_SMALL \
	  -r $TEMP_Output/small_Affine.mat,-1 $TEMP_Output/small_inv_warp.nii.gz

	# Step 3: map warped landmarks to full size
	echoV "Step 3: map warped landmarks to full size"
	echoV "cat $LM_WARPED_SMALL \
	  | awk -F, -v wbig=$Size_W_big -v hbig=$Size_H_big \
	    -v wsmall=$Size_W_init -v hsmall=$Size_H_init \
	    'BEGIN {printf(",X,Y\n")} {printf("%d,%f,%f\n",NR-1,(($1+0.5)*wbig)/wsmall,(($2+0.5)*hbig)/hsmall)}' > $LM_WARPED_FULL"
	cat $LM_WARPED_SMALL \
	  | awk -F, -v wbig=$Size_W_big -v hbig=$Size_H_big \
	    -v wsmall=$Size_W_init -v hsmall=$Size_H_init \
	    'BEGIN {printf(",X,Y\n")} {printf("%d,%f,%f\n",NR-1,(($1+0.5)*wbig)/wsmall,(($2+0.5)*hbig)/hsmall)}' > $LM_WARPED_FULL
	
	end=`date +%s`
	runtime_landmarks=$(($end-$start))
	echo "Apply transformation to landmarks took :" $runtime_landmarks" secondes"
fi

if [ $apply_small_res -eq 1 ];then
	# Create sshot
	echo "------------------------------------------------------------------------------------------"
	echo "Applying on small grayscale images..."
	start=`date +%s`
	#!!!! APPLYING ON GRAYSCALE IMAGES !!!

	# Reslice small source padded
	echoV "$greedy_executable -d 2 \
	-rf $TEMP_Output/new_small_target_padded.nii.gz \
	-rm $TEMP_Output/new_small_source_padded.nii.gz $TEMP_Output/small_registeredImage.nii.gz \
	-r $TEMP_Output/small_warp.nii.gz $TEMP_Output/small_Affine.mat"
	$greedy_executable -d 2 \
	-rf $TEMP_Output/new_small_target_padded.nii.gz \
	-rm $TEMP_Output/new_small_source_padded.nii.gz $TEMP_Output/small_registeredImage.nii.gz \
	-r $TEMP_Output/small_warp.nii.gz $TEMP_Output/small_Affine.mat

	# Create directory to store result
	mkdir -p $TEMP_Output/sshot/
	mkdir -p $PATH_Output/sshot/

	# Convert moving, target and resliced image to PNG file
	echoV "Convert NIFTI to PNG"
	echoV "Target"
	echoV "$c2d_executable $TEMP_Output/new_small_target_padded.nii.gz \
	-type uchar \
	-o $TEMP_Output/sshot/new_small_target.png"
	$c2d_executable $TEMP_Output/new_small_target_padded.nii.gz \
	-type uchar \
	-o $TEMP_Output/sshot/new_small_target.png


	echoV "Source"
	echoV "$c2d_executable $TEMP_Output/new_small_source_padded.nii.gz \
	-type uchar \
	-o $TEMP_Output/sshot/new_small_source.png"
	$c2d_executable $TEMP_Output/new_small_source_padded.nii.gz \
	-type uchar \
	-o $TEMP_Output/sshot/new_small_source.png

	echoV "resliced source"
	echoV "$c2d_executable $TEMP_Output/small_registeredImage.nii.gz \
	-type uchar \
	-o $TEMP_Output/sshot/small_registeredImage.png"
	$c2d_executable $TEMP_Output/small_registeredImage.nii.gz \
	-type uchar \
	-o $TEMP_Output/sshot/small_registeredImage.png


	mv $TEMP_Output/sshot/new_small_target.png $PATH_Output/sshot/new_small_target.png
	mv $TEMP_Output/sshot/new_small_source.png $PATH_Output/sshot/new_small_source.png
	mv $TEMP_Output/sshot/small_registeredImage.png $PATH_Output/sshot/small_registeredImage.png

	end=`date +%s`
	runtime_resl_small=$(($end-$start))
	echo "Apply transformation to small grayscale images took :" $runtime_resl_small" secondes"
fi

# If asked by user, apply transformation to full size images.
if [[ $apply_full_res -eq 1 ]];then

	echo "------------------------------------------------------------------------------------------"
	echo "Applying on full scale images..."
	# Start new timer
	start=`date +%s`

	echoV "Modifying small warp..."
	echoV "Full resolution size : "$Size_W_big"x"$Size_H_big
	# Resample small warp image to this resolution and scale it with the scale we resampled the image to. (the warp image is a matrix that contains a translation vector for each pixel of the target image, we need to scale this translation to the new resolution as we did for the affine matrix)
	echoV "Resampling small warp to full resolution with padding..."
	echoV "$c2d_executable -mcs $TEMP_Output/small_warp_no_pad_trim.nii.gz \
	-foreach \
	-resample $Size_W_big"x"$Size_H_big \
	-scale $factor \
	-spacing 1x1mm -origin 0x0mm \
	-endfor \
	-omc $TEMP_Output/big_warp.nii.gz"
	$c2d_executable -mcs $TEMP_Output/small_warp_no_pad_trim.nii.gz \
	-foreach \
	-resample $Size_W_big"x"$Size_H_big \
	-scale $factor \
	-spacing 1x1mm -origin 0x0mm \
	-endfor \
	-omc $TEMP_Output/big_warp.nii.gz

	echoV "Converting source and target to nifti files with good orientation, pixel spacing and origin..."
	echoV "Target"
	# Convert source and target images to NIFTI files after fixing their orientation, pixel spacing and origin.
	echoV "$c2d_executable -mcs $fixed \
	-foreach \
	-orient LP -spacing 1x1mm -origin 0x0mm \
	-endfor \
	-omc $TEMP_Output/new_target.nii.gz"
	$c2d_executable -mcs $fixed \
	-foreach \
	-orient LP -spacing 1x1mm -origin 0x0mm \
	-endfor \
	-omc $TEMP_Output/new_target.nii.gz

	echoV "Source"
	echoV "$c2d_executable -mcs $moving \
	-foreach -orient LP -spacing 1x1mm -origin 0x0mm \
	-endfor \
	-omc $TEMP_Output/new_source.nii.gz"
	$c2d_executable -mcs $moving \
	-foreach -orient LP -spacing 1x1mm -origin 0x0mm \
	-endfor \
	-omc $TEMP_Output/new_source.nii.gz


	# Change full resolution warp image origin so it matches the one of the source and target images.
	echoV "Modifying origin of mask..."
	echoV "$c2d_executable -mcs $TEMP_Output/big_warp.nii.gz \
	-foreach \
	-origin 0x0mm \
	-endfor \
	-omc $TEMP_Output/big_warp.nii.gz"
	$c2d_executable -mcs $TEMP_Output/big_warp.nii.gz \
	-foreach \
	-origin 0x0mm \
	-endfor \
	-omc $TEMP_Output/big_warp.nii.gz

	# Apply transformation to full resolution images.
	echoV "Applying transformation to full size images..."
	echoV "$greedy_executable -d 2 \
	-rf $TEMP_Output/new_target.nii.gz \
	-rm $TEMP_Output/new_source.nii.gz $TEMP_Output/registeredImage.nii.gz \
	-r $TEMP_Output/big_warp.nii.gz $TEMP_Output/Affine.mat"
	$greedy_executable -d 2 \
	-rf $TEMP_Output/new_target.nii.gz \
	-rm $TEMP_Output/new_source.nii.gz $TEMP_Output/registeredImage.nii.gz \
	-r $TEMP_Output/big_warp.nii.gz $TEMP_Output/Affine.mat

	end=`date +%s`
	runtime_resl_full_res=$(($end-$start))
	echo "Reslicing the full resolution images took :" $runtime_resl_full_res" secondes"


	mkdir -p $TEMP_Output/sshot/full_res

	echo "Converting to PNGs..."
	$c2d_executable -mcs $TEMP_Output/new_target.nii.gz -foreach -type uchar -endfor -omc $TEMP_Output/sshot/full_res/new_target.png
	echo "1/3 done..."
	$c2d_executable -mcs $TEMP_Output/new_source.nii.gz -foreach -type uchar -endfor -omc $TEMP_Output/sshot/full_res/new_source.png
	echo "2/3 done..."
	$c2d_executable -mcs $TEMP_Output/registeredImage.nii.gz -foreach -type uchar -endfor -omc $TEMP_Output/sshot/full_res/registeredImage.png
	echo "3/3 done."
	
	echo "Moving to output directory.."
	mkdir -p $PATH_Output/sshot/full_res
	mv $TEMP_Output/sshot/full_res/new_target.png $PATH_Output/sshot/full_res/new_target.png
	mv $TEMP_Output/sshot/full_res/new_source.png $PATH_Output/sshot/full_res/new_source.png
	mv $TEMP_Output/sshot/full_res/registeredImage.png $PATH_Output/sshot/full_res/registeredImage.png

fi


start=`date +%s`
echo "******************************************************************************"
echo "Saving metrics..."
mv $TEMP_Output/small_Affine.mat $PATH_Output/metrics/small_Affine.mat
mv $TEMP_Output/small_warp.nii.gz $PATH_Output/metrics/small_warp.nii.gz
mv $TEMP_Output/small_inv_warp.nii.gz $PATH_Output/metrics/small_inv_warp.nii.gz

if [[ $apply_full_res -eq 1 ]];then
	mkdir -p $PATH_Output/metrics/full_res
	mv $TEMP_Output/Affine.mat $PATH_Output/metrics/full_res/Affine.mat
	mv $TEMP_Output/big_warp.nii.gz $PATH_Output/metrics/full_res/warp.nii.gz
fi


if [[ $SAVE -eq 1 ]];then
	echo "Saving NIFTIs..."
	mkdir -p $PATH_Output/Saved_NIFTIs
	mv $TEMP_Output/new_small_target_padded.nii.gz $PATH_Output/Saved_NIFTIs/new_small_target_padded.nii.gz
	mv $TEMP_Output/new_small_source_padded.nii.gz $PATH_Output/Saved_NIFTIs/new_small_source_padded.nii.gz
	if [[ $apply_small_res -eq 1 ]];then
		mv $TEMP_Output/small_registeredImage.nii.gz $PATH_Output/Saved_NIFTIs/small_registeredImage.nii.gz
	fi
	if [[ $apply_full_res -eq 1 ]];then
		mkdir -p $PATH_Output/Saved_NIFTIs/full_res
		mv $TEMP_Output/new_target.nii.gz $PATH_Output/Saved_NIFTIs/full_res/new_target.nii.gz
		mv $TEMP_Output/new_source.nii.gz $PATH_Output/Saved_NIFTIs/full_res/new_source.nii.gz
		mv $TEMP_Output/registeredImage.nii.gz $PATH_Output/Saved_NIFTIs/full_res/registeredImage.nii.gz
	fi
fi

end=`date +%s`
runtime_saving=$(($end-$start))
echo "Saving files took :" $runtime_saving" secondes."
echo "Preprocess took : "$runtime_preproc" secondes." > $PATH_Output/Time.txt
echo "Registration took : "$runtime_reg" secondes." >> $PATH_Output/Time.txt
echo "Converting metrics to full scale took : "$runtime_small_to_big" secondes." >> $PATH_Output/Time.txt

if [ $landmarks_provided -eq 1 ];then
	echo "Reslincing landmarks took : "$runtime_landmarks" secondes." >> $PATH_Output/Time.txt
fi
if [ $apply_small_res -eq 1 ];then
	echo "Reslincing small grayscale padded images took : "$runtime_resl_small" secondes." >> $PATH_Output/Time.txt
fi
if [[ $apply_full_res -eq 1 ]];then
	echo "Reslincing full resolution original RGB images took : "$runtime_resl_full_res" secondes." >> $PATH_Output/Time.txt
fi
end_full_script=`date +%s`
runtime_full_script=$(($end_full_script-$start_full_script))
echo "End."
echo "Full script took : "$runtime_full_script" secondes." >> $PATH_Output/Time.txt
echo "Script took : "$runtime_full_script" seconds to run."



