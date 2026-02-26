clear; clc; close all;

Fs       = 10e3;
N        = 256;
n        = (0:N-1).';
L        = 64;

wc_norm = 0.2;
h       = fir1(L-1, wc_norm, 'low');
f_low  = 500;
f_high = 2500;

x_low  = 1.0 * sin(2*pi*f_low  * n/Fs);
x_high = 0.5 * sin(2*pi*f_high * n/Fs);

x      = x_low + x_high;

scale_q15 = 2^15 - 1;

x_q15 = round(x * scale_q15);
h_q15 = round(h * scale_q15);

x_q15 = max(min(x_q15,  32767), -32768);
h_q15 = max(min(h_q15,  32767), -32768);

x_q15 = int16(x_q15);
h_q15 = int16(h_q15);

x_int = int32(x_q15);
h_int = int32(h_q15);

y_q79_int = zeros(N,1,'int16');
for n_idx = 1:N
    acc = int64(0);
    for k = 0:L-1
        x_idx = n_idx - k;
        if x_idx >= 1 && x_idx <= N
            acc = acc + int64(x_int(x_idx)) * int64(h_int(k+1));
        end
    end

    acc_shifted = bitshift(acc, -21);
    if acc_shifted >  32767
        acc_shifted = 32767;
    elseif acc_shifted < -32768
        acc_shifted = -32768;
    end

    y_q79_int(n_idx) = int16(acc_shifted);
end

y_gold_unquant_double = filter(h, 1, x);
y_gold_unquant_f32    = single(y_gold_unquant_double);

x_q15_real = double(x_q15) / (2^15);
h_q15_real = double(h_q15) / (2^15);

y_gold_q15stim_double = filter(h_q15_real, 1, x_q15_real);
y_gold_q15stim_f32    = single(y_gold_q15stim_double);

write_hex16_file('x_q15_in_hex.txt',  x_q15);
write_hex16_file('cmem_in_hex.txt',   h_q15);
write_hex16_file('y_q79_out.txt',     y_q79_int);

write_f32_dec_file('y_f32_gold_unquant.txt',        y_gold_unquant_f32);
write_f32_hex_file('y_f32_gold_unquant_hex.txt',    y_gold_unquant_f32);

write_f32_dec_file('y_f32_gold_q15stim.txt',        y_gold_q15stim_f32);
write_f32_hex_file('y_f32_gold_q15stim_hex.txt',    y_gold_q15stim_f32);

fprintf('Wrote x_q15_in_hex.txt, cmem_in_hex.txt, y_q79_out.txt\n');
fprintf('Wrote y_f32_gold_unquant(.txt/_hex.txt) and y_f32_gold_q15stim(.txt/_hex.txt)\n');

x_real = double(x_q15)    / (2^15);
y_real = double(y_q79_int)/ (2^9);

t = n / Fs;

figure;
subplot(2,1,1);
plot(t, x_real, 'LineWidth', 1); grid on;
xlabel('Time (s)');
ylabel('Amplitude');
title('Input signal x[n]');

subplot(2,1,2);
plot(t, y_real, 'LineWidth', 1); grid on;
xlabel('Time (s)');
ylabel('Amplitude');
title('y[n]');

Nfft = 1024;
Xf = fft(x_real, Nfft);
Yf = fft(y_real, Nfft);
faxis = (0:Nfft-1)/Nfft*Fs;

figure;
subplot(2,1,1);
plot(faxis, 20*log10(abs(Xf)+1e-12)); grid on;
xlim([0 Fs/2]);
xlabel('Frequency (Hz)');
ylabel('|X(f)| (dB)');
title('Input spectrum');

subplot(2,1,2);
plot(faxis, 20*log10(abs(Yf)+1e-12)); grid on;
xlim([0 Fs/2]);
xlabel('Frequency (Hz)');
ylabel('|Y(f)| (dB)');
title('Output spectrum');

uiwait(gcf);

function write_hex16_file(filename, data_int16)
    data_int16 = int16(data_int16(:));
    fid = fopen(filename, 'w');
    if fid < 0, error('Could not open %s for writing.', filename); end
    for k = 1:length(data_int16)
        v = int32(data_int16(k));
        if v < 0, v = v + 2^16; end
        fprintf(fid, '%04X\n', v);
    end
    fclose(fid);
end

function write_f32_dec_file(filename, data_single)
    data_single = single(data_single(:));
    fid = fopen(filename, 'w');
    if fid < 0, error('Could not open %s for writing.', filename); end
    for k = 1:length(data_single)
        fprintf(fid, '%.9g\n', data_single(k));
    end
    fclose(fid);
end

function write_f32_hex_file(filename, data_single)
    data_single = single(data_single(:));
    u32 = typecast(data_single, 'uint32');
    fid = fopen(filename, 'w');
    if fid < 0, error('Could not open %s for writing.', filename); end
    for k = 1:length(u32)
        fprintf(fid, '%08X\n', u32(k));
    end
    fclose(fid);
end
