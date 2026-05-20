projectRoot = fileparts(mfilename("fullpath"));
addpath(fullfile(projectRoot, "src"));

app = nav_ui_app(projectRoot); %#ok<NASGU>
