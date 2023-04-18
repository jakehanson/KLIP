function KLIP, structure, im_size,  k_klip, checkpoint = checkpoint
;Function to create PSF subtracted image using KLIP algorithm
;The target image is currently the first image in the PSF cube
;STRUCTURE - Output from search_zones.pro
;IM_SIZE - Dimension of square subarray
;K_KLIP - Number of KL Basis Vectors to retain

print, '--[ KLIP    ]-- STARTING'

;seperate structure elements
ringseg = structure.ringseg
mask_index = structure.mask_index
structure = 0.0  ; free memory


;store number of images, rings, and angular segments in ringseg
nimages = (size(ringseg))(1)
nrings = (size(ringseg))(2)
n_ang = (size(ringseg))(3)
data = (size(ringseg))(4)

;Set dimensions of single frame
n_cols = im_size
n_rows = im_size

final_arr = fltarr(n_cols,n_rows)  ; final array same size as sub array

final_arr[*] = !values.f_nan

full_lib = fltarr(nimages-1,nrings,n_ang,data)  ; Define array for psf lib

for aa = 0, nimages-2 do begin

   full_lib[aa,*,*,*] = ringseg[aa+1,*,*,*]  ; Remove target image from psf lib

endfor

;store number of images in psf lib
nimages = (size(full_lib))(1)

progress_counter = 0.0          ; initialize progress counter
total_elements = nrings*n_ang   ; also used for progress update


;Build final image segment by segment:
for ii=0, nrings-1 do begin
  
   for jj=0, n_ang-1 do begin


;first, we get the data from our target segment (the one we will
;project onto KL basis


      target_seg = ringseg[0,ii,jj,*]

      target_seg = reform(target_seg) ; should be 1d (with Ndata points)
      dense_target = target_seg[where(finite(target_seg) eq 1,/null)] ; Remove NaN   

      if dense_target eq !NULL then begin
         
         print, 'ERROR: EMPTY SEARCH ZONE'
         print,'MAKE SURE ALL SEARCH ZONES CONTAIN >1 PIXELS'

      endif

      dense_target = dense_target - total(dense_target)/n_elements(dense_target)  ; subtract mean
      dense_target = transpose(dense_target)  ; 1XN
      index = where(finite(mask_index[ii,jj,*]) eq 1,/null)  ; get segment index

      size_target = n_elements(dense_target)
      size_mask = n_elements(index)
      if size_target ne size_mask then print, 'MASK NOT SAME SIZE AS DATA'


;next, we will create our KL basis

     
      ;store the segments of interest
      data_seg = full_lib[*,ii,jj,*]   ; create psf lib for segment

      dense_data = reduce_matrix(data_seg)     ; Condense Matrix (rid NaN)

      size_data = (size(dense_data))(2)
      
      ;If the segment contains only a single pixel then dense_data is 1d matrix
      if size_target eq 1 then begin

         print, '(WARNING!) Some Search Zones Contain Only 1 Pixel...'
         
         size_data = 1

      endif

      if size_target ne size_data then print, 'TARGET SEG NOT SAME SIZE AS DATA SEG'

      kl_basis = get_klip_basis(dense_data, k_klip) ; CREATE BASIS!

      ;if checkpoint eq 13 then begin ; special checkpoint to print eigenimg.

      ;   n_rows = (size(kl_basis))(2)

      ;   eigenimage=reform(kl_basis[0,*])  ; make eigenimage 1d

      ;   for mm = 0, n_rows-1 do begin  ; loop over eigenimage

      ;      final_arr[index[mm]] = eigenimage[mm]

      ;   endfor
         
      ;endif


;last, we will project our target image onto our KL basis


      synthetic_1d = dense_target # matrix_multiply(kl_basis,kl_basis,/atranspose)  ; create psf reconstruction
      
      synthetic_1d = dense_target - synthetic_1d ; subtract psf reconstruction     
      
      for cc = 0, n_elements(index)-1 do begin
         
         final_arr[index[cc]] = synthetic_1d[cc] ; Build Final Image
         
      endfor

      print, '--[ KLIP    ]-- COMPLETE SEGMENTS: ',progress_counter,'/',total_elements

      progress_counter = progress_counter + 1 ; update progress

   endfor
   
endfor


print, '--[ KLIP    ]-- COMPLETE'

return, final_arr

END
