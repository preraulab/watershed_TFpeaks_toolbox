function filtdata = SW_filt_500Hz(data)
%SW_FILT_500HZ Returns a discrete-time filter object.

% MATLAB Code
% Generated by MATLAB(R) 9.2 and the Signal Processing Toolbox 7.4.
% Generated on: 12-Sep-2018 20:36:39

% Equiripple Bandpass filter designed using the FIRPM function.

% All frequency values are in Hz.
Fs = 500;  % Sampling Frequency

Fstop1 = 0.1;             % First Stopband Frequency
Fpass1 = 0.3;             % First Passband Frequency
Fpass2 = 1.5;             % Second Passband Frequency
Fstop2 = 1.8;             % Second Stopband Frequency
Dstop1 = 0.001;           % First Stopband Attenuation
Dpass  = 0.057501127785;  % Passband Ripple
Dstop2 = 0.0001;          % Second Stopband Attenuation
dens   = 20;              % Density Factor

% Calculate the order from the parameters using FIRPMORD.
[N, Fo, Ao, W] = firpmord([Fstop1 Fpass1 Fpass2 Fstop2]/(Fs/2), [0 1 ...
                          0], [Dstop1 Dpass Dstop2]);

% Calculate the coefficients using the FIRPM function.
b  = firpm(N, Fo, Ao, W, {dens});
Hd = dfilt.dffir(b);
delay=ceil(N/2);

%Filter the data and return result
filtfull=filter(Hd,[data(1)*ones(1,N) data]);
filtdata=[filtfull((delay+N+1):end) zeros(1,ceil(N/2))];
% [EOF]