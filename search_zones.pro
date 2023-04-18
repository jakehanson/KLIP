function search_zones,imagecube,ringsize,n_ang

print, '--[ SEARCH_ZONES    ]-- STARTING'

;Get the dimensions of a single frame
x = (size(imagecube))(1)
y = (size(imagecube))(2)

x = double(x)
y = double(y)

;Make sure array is square
if x ne y then begin 
  if x lt y then y = x else x = y ;Use a square of the smaller dimension
endif

imagecube[where(finite(imagecube) eq 0)] = 0.00  ; Can't have NaN

  ;How many frames do we have?
  nimages = (size(imagecube))(3)

;Check that ringsize is valid
if ringsize gt x/2. then begin
  print, 'Ring Size larger than image, using max ring size instead'
  ringsize = round(x/2.)  ; Use max ring size (in integer pixels)
  if x/2. - ringsize lt 0. then ringsize = ringsize - 1.  ; Be sure to round down
endif

;How many rings?
  nrings = round(.5*x/ringsize)  ; Use greatest number of rings possible
  if x/ringsize - nrings lt 0. then nrings = nrings - 1. ; round down

;Make sure we have integer number of angular segments
if 360. mod n_ang ne 0. then begin
  print, '360 not divisible by angle size, using 10 angle segments instead'
  n_ang = 10.
endif


;Total number of data points?
  ndatapoints = x*x ; Data array for a single image is a square

;Define our final data arrays

  structure = {ringseg:fltarr(nimages,nrings,n_ang,ndatapoints), mask_index:fltarr(nrings,n_ang,ndatapoints)}

structure.ringseg[ * ] = !values.f_nan
structure.mask_index[ * ] = !values.f_nan


;========================================================
; We will first define two general masks, one for radial
; distance and one for angular value (in radians)
;=========================================================

  distmask = imagecube[*,*,0]  ; use the first image in cube to create mask
  N = x  ; Define the size of N x N output array
  dist_circle, distmask, N, [x/2., y/2.]  ; create distance mask
  writefits, 'distmask.fits', distmask

  print, '--[ SEARCH_ZONES    ]-- DISTANCE MASK COMPLETE'
 
  anglemask = imagecube[*,*,0]  ; use the first image in cube to create mask

;Define Mask by Pixel
for xx=0, x-1 do begin
  for yy=0, y-1 do begin

     ;Define angle on just the axes
     if yy eq y/2. and xx ge x/2. then anglemask[xx,yy] = 0.
     if xx eq x/2. and yy ge y/2. then anglemask[xx,yy] = !pi/2.
     if yy eq y/2. and xx le x/2. then anglemask[xx,yy] = !pi
     if xx eq x/2. and yy le y/2. then anglemask[xx,yy] = 3.*!pi/2.

     ;Define angles where atan is defined (4 cases because atan is not unique)
     if xx gt x/2. and yy gt y/2. then anglemask[xx,yy] = atan((yy-y/2.)/(xx-x/2.))
     if xx lt x/2. and yy gt y/2. then anglemask[xx,yy] = atan((x/2.-xx)/(yy-y/2.))+!pi/2.
     if xx lt x/2. and yy lt y/2. then anglemask[xx,yy] = atan((y/2.-yy)/(x/2.-xx))+!pi
     if xx gt x/2. and yy lt y/2. then anglemask[xx,yy] = atan((xx-x/2.)/(y/2.-yy))+3.*!pi/2.

  endfor
endfor

writefits, 'anglemask.fits',anglemask

print, '--[ SEARCH_ZONES    ]-- ANGLE MASK COMPLETE'

;========================================================
; Next we will loop over images, rings, and angles in 
; order to store data in ringseg array
;=========================================================


;Loop over image
for ii=0, nimages-1 do begin

;Break frame into rings
  for jj=0, nrings-1 do begin
    ringmask = imagecube[*,*,ii]  ; Get Frame

    r_inner = jj*ringsize
    r_outer = (jj+1)*ringsize

    ringmask[where(distmask ge r_outer or distmask lt r_inner)] = !values.f_nan
    
;Break rings into angular segments
    for kk=0,n_ang-1  do begin

      segmask = ringmask  ; start with ringmask
     
      minang = kk*360./n_ang    
      minang = !pi/180.*minang  ; Convert to radians
      maxang = (kk+1)*360./n_ang
      maxang = !pi/180.*maxang  ; Convert to radians
      
      segmask[where(anglemask ge maxang or anglemask lt minang)] = !values.f_nan

      if ii eq 0 then begin

         structure.mask_index[jj,kk,*]=segmask ; find mask index for first image

      endif

      segmask = segmask[where(finite(segmask) eq 1)] ; Use only finite values and convert to 1-D array

      structure.ringseg[ii, jj, kk, 0:n_elements(segmask)-1] = segmask ; add current seg to final array

   endfor  ; Loop over images
 endfor  ; Loop over rings
endfor  ; Loop over angular segments

print, '--[ SEARCH_ZONES    ]-- COMPLETE'

return, structure  ; Send back final data array

end

