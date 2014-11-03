CREATE TEMPORARY VIEW covariate AS
  SELECT gridcode,
         featureid,
         sourcefc,
         areasqkm,
         totdasqkm,
         lengthkm,
         reachslope,
         forest,
         herbacious,
         agricultur,
         herb_or_ag,
         developed,
         develnotop,
         undev_fore,
         impervious,
         conus_opnw,
         conus_wetl,
         tmax_ann,
         tmin_ann,
         prcp_winte,
         prcp_ann,
         dep_no3,
         dep_so4,
         slope_deg,
         neny_drain,
         neny_hygrp,
         neny_hyg_1,
         neny_hyg_2,
         neny_hyg_3,
         neny_hyg_4,
         surfcoar_2,
         surfcoar_3,
         percent_sa,
         reachelev,
         elev_nalcc,
         presenceab,
         tmax_f,
         tmin_f,
         prcpwin_in,
         prcpann_in
  FROM gis.catchments;

\COPY (SELECT * FROM covariate LIMIT 5) TO 'covariateData.csv' CSV HEADER;