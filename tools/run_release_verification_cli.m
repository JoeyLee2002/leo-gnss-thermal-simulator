try
    run_release_verification_isolated;
    % Do not call exit here. MATLAB R2021b can raise a native heap error
    % while tearing down a long mixed graphics/numerical batch, after all
    % release artifacts have already been written successfully.
    return;
catch exception
    fprintf(2, '%s\n', getReport(exception, 'extended'));
    error('leotherm:ReleaseVerificationFailed', ...
        'Release verification failed: %s', exception.message);
end
